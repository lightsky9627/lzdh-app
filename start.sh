#!/bin/sh

echo ">>> 启动 PHP-FPM..."
php-fpm -D

echo ">>> 等待 PHP-FPM 启动..."
sleep 2

echo ">>> 启动 Nginx..."
nginx -g 'daemon off;'
