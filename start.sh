#!/bin/sh

# 1. 探测是初次安装，亦或是升级？
set -e

INSTALL_LOCK=/var/www/html/runtime/install.lock

echo "等待数据库连接..."
until mysqladmin ping -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" --silent; do
    sleep 2
done
echo "数据库已连接。"

if [ ! -f "$INSTALL_LOCK" ]; then
    echo "install.lock 不存在，探测数据库是否已完成安装..."

    ADMIN_COUNT=$(mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" -N -e \
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='lz_admin';" 2>/dev/null || echo 0)

    if [ "$ADMIN_COUNT" = "1" ]; then
        HAS_ADMIN=$(mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" -N -e \
          "SELECT COUNT(*) FROM ${DB_NAME}.lz_admin;" 2>/dev/null || echo 0)

        if [ "$HAS_ADMIN" -gt 0 ]; then
            echo "检测到管理员账号已存在，自动生成 install.lock，跳过安装向导。"
            mkdir -p /var/www/html/runtime
            echo "$(date '+%Y-%m-%d %H:%M:%S')/" > "$INSTALL_LOCK"
        else
            echo "lz_admin 表存在但为空，说明安装未完成，进入安装向导。"
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
