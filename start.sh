#!/bin/sh
set -e

INSTALL_LOCK=/var/www/html/runtime/install.lock
ENV_FILE=/var/www/html/.env

echo "等待数据库连接..."
until mysqladmin ping -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --silent; do
    sleep 2
done
echo "数据库已连接。"

if [ ! -f "$INSTALL_LOCK" ] || [ ! -f "$ENV_FILE" ]; then
    ADMIN_COUNT=$(mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" -N -e \
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='${DB_PREFIX:-lz_}admin';" 2>/dev/null || echo 0)

    if [ "$ADMIN_COUNT" = "1" ]; then
        HAS_ADMIN=$(mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" -N -e \
          "SELECT COUNT(*) FROM ${DB_NAME}.${DB_PREFIX:-lz_}admin;" 2>/dev/null || echo 0)

        if [ "$HAS_ADMIN" -gt 0 ]; then
            echo "检测到管理员账号已存在，自动补齐 install.lock 和 .env。"
            mkdir -p /var/www/html/runtime

            [ -f "$INSTALL_LOCK" ] || echo "$(date '+%Y-%m-%d %H:%M:%S')/" > "$INSTALL_LOCK"

            if [ ! -f "$ENV_FILE" ] || [ ! -s "$ENV_FILE" ]; then
                cat > "$ENV_FILE" << EOF
APP_DEBUG = false
INSTALL_ID = DOCKER-AUTO-GEN
DB_DRIVER = mysql
DB_TYPE = mysql
DB_HOST = ${DB_HOST}
DB_NAME = ${DB_NAME}
DB_USER = ${DB_USER}
DB_PASS = ${DB_PASS}
DB_PORT = ${DB_PORT}
DB_CHARSET = utf8mb4
DB_PREFIX = ${DB_PREFIX:-lz_}
IS_DEV = false
DEFAULT_LANG = zh-cn
VITE_INDEX_PORT = 15001
VITE_ADMIN_PORT = 15002
EOF
            fi

            chown www-data:www-data "$INSTALL_LOCK" "$ENV_FILE"
        else
            echo "lz_admin 表存在但为空，进入安装向导。"
        fi
    else
        echo "数据库未初始化，进入安装向导。"
    fi
fi

echo ">>> 启动 PHP-FPM..."
php-fpm -D

echo ">>> 等待 PHP-FPM 启动..."
sleep 2

echo ">>> 启动 Nginx..."
nginx -g 'daemon off;'
