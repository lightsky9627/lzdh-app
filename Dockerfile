# 使用 PHP 8.0 FPM Alpine 作为基础镜像
FROM php:8.0-fpm-alpine

# 设置构建参数
ARG APP_VERSION=v251201
ARG SOURCE_URL

# 安装 Nginx 和必要的 PHP 扩展
RUN apk add --no-cache \
    nginx \
    wget \
    unzip \
    && docker-php-ext-install mysqli pdo pdo_mysql \
    && rm -rf /var/cache/apk/*

# 创建必要的目录
RUN mkdir -p /var/www/html \
    && mkdir -p /run/nginx \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/log/php \
    && chown -R www-data:www-data /var/www/html

# 下载并解压源码
WORKDIR /tmp
RUN wget -O app.zip "${SOURCE_URL}" \
    && unzip app.zip -d /var/www/html/ \
    && rm app.zip \
    && chown -R www-data:www-data /var/www/html

# 复制 Nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf

# 复制启动脚本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# 设置工作目录
WORKDIR /var/www/html

# 启动服务
CMD ["/start.sh"]
