# 粒子导航 Docker 版

将 [粒子导航](https://lzdh.lovestu.com/) 打包为单个 Docker 镜像（Alpine + Nginx + PHP 8.0-FPM），配合 MySQL 容器实现一键部署。

## 🚀 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/lightsky9627/lzdh-app.git && cd lzdh-app

# 2. 创建 .env 并修改数据库密码
cp .env.example .env
vim .env   # 至少修改 MYSQL_ROOT_PASSWORD 和 MYSQL_PASSWORD

# 3. 启动
docker compose up -d

# 4. 查看自动生成的管理员密码
docker compose logs lzdh-app | grep "密  码"
```

- **首页**: `http://IP:65002`
- **后台**: `http://IP:65002/lz-admin`

## ⚙️ 关键配置

### 文件权限（解决上传头像/图标失败）

容器内 PHP 使用 `PUID`/`PGID` 指定的 UID/GID 运行。**必须与宿主机 `./data` 目录的属主一致**，否则无法写入上传文件。

```bash
# 查看当前用户的 UID/GID
id -u && id -g
# 输出 1000 / 1000 → .env 中设置 PUID=1000 PGID=1000（默认值）

# 如果宿主机 data/ 由 root 创建，可手动修正:
sudo chown -R 1000:1000 ./data
```

### .env 配置项说明

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MYSQL_ROOT_PASSWORD` | *必填* | MySQL root 密码 |
| `MYSQL_DATABASE` | `lzdh` | 数据库名 |
| `MYSQL_USER` | `lzdh` | 数据库用户 |
| `MYSQL_PASSWORD` | *必填* | 数据库密码 |
| `WEB_PORT` | `65002` | 宿主机端口 |
| `PUID` / `PGID` | `1000` | 容器内 PHP 运行的 UID/GID |
| `AUTO_INSTALL` | `true` | 首次启动自动建表建管理员；设为 `false` 走网页安装向导 |
| `ADMIN_USER` | `admin` | 自动创建的管理员用户名 |
| `ADMIN_PASSWORD` | *(随机)* | 管理员密码，留空则自动生成（日志中查看） |
| `DB_PREFIX` | `lz_` | 数据表前缀 |
| `APP_DEBUG` | `false` | 调试模式 |

### 安装方式选择

**方式 A — 全自动（推荐）**

`.env` 中 `AUTO_INSTALL=true`（默认），启动后数据库表和管理员账号自动创建。

**方式 B — 网页安装向导**

```env
AUTO_INSTALL=false
```

启动后访问 `http://IP:65002`，会自动跳转安装向导页面。安装向导中的数据库主机名填 `mysql`。

## 📂 数据持久化

```
./data/storage/    → /var/www/html/public/storage   (上传文件：头像、图标、附件)
./data/runtime/    → /var/www/html/runtime           (缓存、会话、install.lock)
./logs/nginx/      → /var/log/nginx                  (Nginx 日志)
./logs/php/        → /var/log/php                    (PHP 错误日志)
MySQL 数据         → Docker named volume (lzdh-db-data)
```

> 迁移时备份 `./data/` 目录 + MySQL 数据即可。

## 🔍 诊断

```bash
# 检查容器内权限、数据库连接、安装状态
docker compose exec lzdh-app docker-entrypoint.sh doctor
```

## 🛠️ 构建自己的镜像

```bash
chmod +x build.sh
./build.sh
# 交互式输入版本号、镜像名、源码URL
```

## 📁 文件结构

| 文件 | 说明 |
|------|------|
| `Dockerfile` | 基于 `php:8.0-fpm-alpine`，集成 Nginx + PHP-FPM |
| `docker-entrypoint.sh` | 入口脚本：PUID/PGID 映射、目录权限修正、数据库初始化 |
| `bootstrap.php` | PHP 引导脚本：等待数据库、导表、创建管理员、同步 .env |
| `nginx.conf` | Nginx 配置：ThinkPHP 伪静态、上传目录安全、unix socket |
| `php/php.ini` | PHP 运行时配置：上传大小、时区、OPcache |
| `php/www.conf` | PHP-FPM 池配置：unix socket、环境变量传递 |
| `docker-compose.yaml` | 编排：App + MySQL，卷挂载 |
| `build.sh` | 交互式构建脚本 |

## 📝 注意事项

- 镜像约 130MB（Alpine 基础），支持 amd64 / arm64
- PHP 上传限制已设为 64MB（`php.ini`），Nginx 限制 72MB（`nginx.conf`）
- 上传目录禁止执行 PHP 脚本（安全加固）
- 容器以 root 启动（用于修正挂载目录权限），PHP-FPM 进程以 `PUID:PGID` 身份运行
