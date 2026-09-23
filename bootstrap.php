<?php
/**
 * 粒子导航 Docker 引导脚本（容器内运行，不属于应用源码）
 *
 * 用法:
 *   php bootstrap.php wait-db      等待数据库可用
 *   php bootstrap.php install      按需导入表结构 / 创建管理员
 *   php bootstrap.php sync-env     用容器环境变量生成 .env 与 install.lock
 *   php bootstrap.php doctor       打印诊断信息（权限 / 数据库 / 安装状态）
 */

declare(strict_types=1);

const APP_ROOT = '/var/www/html';

function envs(string $key, string $default = ''): string
{
    $value = getenv($key);
    return ($value === false || $value === '') ? $default : (string)$value;
}

function out(string $msg): void
{
    fwrite(STDOUT, '[bootstrap] ' . $msg . PHP_EOL);
}

function fail(string $msg): void
{
    fwrite(STDERR, '[bootstrap][ERROR] ' . $msg . PHP_EOL);
    exit(1);
}

function dbConfig(): array
{
    return [
        'host'   => envs('DB_HOST', '127.0.0.1'),
        'port'   => envs('DB_PORT', '3306'),
        'name'   => envs('DB_NAME', 'lzdh'),
        'user'   => envs('DB_USER', 'root'),
        'pass'   => envs('DB_PASS', ''),
        'prefix' => envs('DB_PREFIX', 'lz_'),
    ];
}

function pdoConnect(bool $withDatabase = true): PDO
{
    $c = dbConfig();
    $dsn = sprintf(
        'mysql:host=%s;port=%s%s;charset=utf8mb4',
        $c['host'],
        $c['port'],
        $withDatabase ? ';dbname=' . $c['name'] : ''
    );

    return new PDO($dsn, $c['user'], $c['pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_TIMEOUT            => 5,
    ]);
}

function waitDb(int $timeout): PDO
{
    $c = dbConfig();
    $deadline = time() + $timeout;
    $lastError = '';

    while (time() < $deadline) {
        try {
            return pdoConnect(false);
        } catch (Throwable $e) {
            $lastError = $e->getMessage();
            sleep(2);
        }
    }

    fail(sprintf('等待数据库 %s:%s 超时（%ds）：%s', $c['host'], $c['port'], $timeout, $lastError));
    exit(1); // unreachable
}

function tableExists(PDO $pdo, string $table): bool
{
    $c = dbConfig();
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = :s AND table_name = :t'
    );
    $stmt->execute(['s' => $c['name'], 't' => $table]);
    return (int)($stmt->fetch()['n'] ?? 0) > 0;
}

function ensureDatabase(PDO $serverPdo): void
{
    $c = dbConfig();
    $serverPdo->exec(sprintf(
        'CREATE DATABASE IF NOT EXISTS `%s` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci',
        str_replace('`', '', $c['name'])
    ));
}

/**
 * 导入 database/install.sql，并按 DB_PREFIX 替换默认的 lz_ 前缀
 */
function importSchema(PDO $pdo): void
{
    $file = APP_ROOT . '/database/install.sql';
    if (!is_file($file)) {
        fail('未找到 database/install.sql');
    }

    $sql = (string)file_get_contents($file);
    if (str_starts_with($sql, "\xEF\xBB\xBF")) {
        $sql = substr($sql, 3);
    }
    $sql = preg_replace('/^\s*--.*$/m', '', $sql);
    $sql = preg_replace('/\/\*[\s\S]*?\*\//', '', $sql);

    $prefix = dbConfig()['prefix'];
    if ($prefix !== 'lz_') {
        $sql = preg_replace('/\blz_(?=[a-z_]+)/', $prefix, $sql);
    }

    $statements = array_filter(array_map('trim', explode(';', $sql)), fn($s) => $s !== '');
    foreach ($statements as $statement) {
        $pdo->exec($statement);
    }

    out(sprintf('已导入表结构（%d 条语句，前缀 %s）', count($statements), $prefix));
}

function adminCount(PDO $pdo): int
{
    $table = dbConfig()['prefix'] . 'admin';
    if (!tableExists($pdo, $table)) {
        return -1;
    }
    return (int)$pdo->query('SELECT COUNT(*) AS n FROM `' . $table . '`')->fetch()['n'];
}

function createAdmin(PDO $pdo, string $username, string $password): void
{
    $table = dbConfig()['prefix'] . 'admin';
    $now = date('Y-m-d H:i:s');
    $stmt = $pdo->prepare(
        'INSERT INTO `' . $table . '` (`username`,`password`,`nickname`,`avatar`,`status`,`create_time`,`update_time`)'
        . ' VALUES (:u,:p,:n,:a,1,:c,:m)'
    );
    $stmt->execute([
        'u' => $username,
        'p' => password_hash($password, PASSWORD_DEFAULT),
        'n' => '管理员',
        'a' => '',
        'c' => $now,
        'm' => $now,
    ]);
}

function formatEnvValue(string $value): string
{
    if ($value === '') {
        return '';
    }
    if (preg_match('/[\s#;=]/', $value)) {
        return '"' . addcslashes($value, "\"\\") . '"';
    }
    return $value;
}

function readInstallId(string $envPath): string
{
    if (!is_file($envPath)) {
        return '';
    }
    $data = parse_ini_file($envPath, false, INI_SCANNER_RAW) ?: [];
    return (string)($data['INSTALL_ID'] ?? '');
}

function generateInstallId(): string
{
    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    $chars = '';
    $bytes = random_bytes(16);
    for ($i = 0; $i < 16; $i++) {
        $chars .= $alphabet[ord($bytes[$i]) % strlen($alphabet)];
    }
    return 'LZDH-' . implode('-', str_split($chars, 4));
}

/**
 * 每次启动都用容器环境变量重写 .env，
 * 这样改了 compose 里的数据库配置不需要手工进容器改文件。
 */
function syncEnvFile(): void
{
    $c = dbConfig();
    $envPath = APP_ROOT . '/.env';
    $installId = readInstallId($envPath) ?: generateInstallId();

    $lines = [
        'APP_DEBUG = ' . (envs('APP_DEBUG', 'false') === 'true' ? 'true' : 'false'),
        'INSTALL_ID = ' . $installId,
        'DB_DRIVER = mysql',
        'DB_TYPE = mysql',
        'DB_HOST = ' . formatEnvValue($c['host']),
        'DB_NAME = ' . formatEnvValue($c['name']),
        'DB_USER = ' . formatEnvValue($c['user']),
        'DB_PASS = ' . formatEnvValue($c['pass']),
        'DB_PORT = ' . formatEnvValue($c['port']),
        'DB_CHARSET = utf8mb4',
        'DB_PREFIX = ' . formatEnvValue($c['prefix']),
        'IS_DEV = false',
        'DEFAULT_LANG = zh-cn',
        'VITE_INDEX_PORT = 15001',
        'VITE_ADMIN_PORT = 15002',
    ];

    $content = implode("\r\n", $lines) . "\r\n";
    $current = is_file($envPath) ? (string)file_get_contents($envPath) : '';
    if ($current !== $content && file_put_contents($envPath, $content, LOCK_EX) === false) {
        fail('写入 .env 失败，请检查 /var/www/html 是否可写');
    }
    @chmod($envPath, 0640);
    out('.env 已同步');
}

function writeInstallLock(): void
{
    $lock = APP_ROOT . '/runtime/install.lock';
    if (!is_dir(dirname($lock))) {
        @mkdir(dirname($lock), 0775, true);
    }
    if (!is_file($lock)) {
        file_put_contents($lock, date('Y-m-d H:i:s'), LOCK_EX);
        out('已写入 runtime/install.lock');
    }
}

function removeInstallLock(): void
{
    $lock = APP_ROOT . '/runtime/install.lock';
    if (is_file($lock)) {
        @unlink($lock);
        out('已移除 runtime/install.lock（数据库尚未初始化）');
    }
}

// --------------------------------------------------------
// 命令分发
// --------------------------------------------------------
$command = $argv[1] ?? 'doctor';
$timeout = (int)envs('DB_WAIT_TIMEOUT', '120');

switch ($command) {
    case 'wait-db':
        waitDb($timeout);
        out('数据库连接正常');
        break;

    case 'install':
        $serverPdo = waitDb($timeout);
        ensureDatabase($serverPdo);
        $pdo = pdoConnect(true);

        $count = adminCount($pdo);
        $autoInstall = envs('AUTO_INSTALL', 'true') !== 'false';

        if ($count < 0) {
            if (!$autoInstall) {
                out('未检测到数据表，AUTO_INSTALL=false，请访问站点使用安装向导');
                removeInstallLock();
                break;
            }
            out('未检测到数据表，开始自动初始化...');
            importSchema($pdo);
            $count = 0;
        }

        if ($count === 0) {
            if (!$autoInstall) {
                out('数据表已存在但无管理员，请访问站点使用安装向导');
                removeInstallLock();
                break;
            }
            $user = envs('ADMIN_USER', 'admin');
            $pass = envs('ADMIN_PASSWORD', '');
            if ($pass === '') {
                $pass = bin2hex(random_bytes(6));
                out('未设置 ADMIN_PASSWORD，已生成随机密码');
            }
            createAdmin($pdo, $user, $pass);
            out('============================================');
            out('管理员账号已创建');
            out('  后台地址: /lz-admin');
            out('  用户名  : ' . $user);
            out('  密  码  : ' . $pass);
            out('  请登录后立即修改密码！');
            out('============================================');
            $count = 1;
        } else {
            out(sprintf('检测到 %d 个管理员账号，跳过初始化', $count));
        }

        syncEnvFile();
        writeInstallLock();
        break;

    case 'sync-env':
        syncEnvFile();
        break;

    case 'doctor':
    default:
        out('APP_VERSION   : ' . envs('APP_VERSION', 'unknown'));
        out('PHP           : ' . PHP_VERSION);
        $c = dbConfig();
        out(sprintf('DB            : %s@%s:%s/%s (prefix=%s)', $c['user'], $c['host'], $c['port'], $c['name'], $c['prefix']));

        foreach ([APP_ROOT, APP_ROOT . '/runtime', APP_ROOT . '/public/storage', APP_ROOT . '/public/storage/uploads'] as $path) {
            $exists = file_exists($path);
            $stat = $exists ? stat($path) : null;
            out(sprintf(
                '%-34s exists=%s writable=%s owner=%s:%s mode=%s',
                $path,
                $exists ? 'yes' : 'NO',
                ($exists && is_writable($path)) ? 'yes' : 'NO',
                $stat['uid'] ?? '-',
                $stat['gid'] ?? '-',
                $stat ? substr(sprintf('%o', $stat['mode']), -4) : '-'
            ));
        }

        out('.env          : ' . (is_file(APP_ROOT . '/.env') ? 'yes' : 'NO'));
        out('install.lock  : ' . (is_file(APP_ROOT . '/runtime/install.lock') ? 'yes' : 'NO'));

        try {
            $pdo = pdoConnect(true);
            out('数据库连接    : OK，管理员数=' . adminCount($pdo));
        } catch (Throwable $e) {
            out('数据库连接    : 失败 - ' . $e->getMessage());
        }
        break;
}
