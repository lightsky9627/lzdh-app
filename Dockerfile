# ==========================================================
# 粒子导航 (lzdh) 单镜像：Nginx + PHP-FPM + 源码
# ==========================================================
FROM php:8.0-fpm-alpine

ARG APP_VERSION=v1.0.2
ARG SOURCE_URL=https://bit.bravexist.cn/2026/09/lzdh-plus-1.0.2.zip

LABEL org.opencontainers.image.title="lzdh-app" \
      org.opencontainers.image.description="粒子导航 (lzdh) Docker 镜像 (Nginx + PHP-FPM)" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/lightsky9627/lzdh-app"

ENV APP_ROOT=/var/www/html \
    APP_VERSION=${APP_VERSION} \
    TZ=Asia/Shanghai \
    PUID=82 \
    PGID=82

# 运行期依赖 + 构建期工具
#  - shadow : usermod/groupmod，用于 PUID/PGID 映射
#  - su-exec: 以 www-data 身份做写入自检
RUN set -eux; \
    apk add --no-cache nginx tzdata shadow su-exec; \
    apk add --no-cache --virtual .build-deps wget unzip; \
    docker-php-ext-install -j"$(nproc)" mysqli pdo_mysql; \
    docker-php-ext-enable opcache; \
    mkdir -p /run/nginx /var/log/nginx /var/log/php "${APP_ROOT}"

# 下载并解压源码（zip 内部使用反斜杠分隔符，unzip 返回码 1 属于警告）
WORKDIR /tmp
RUN set -eux; \
    wget --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -O app.zip "${SOURCE_URL}"; \
    unzip -o -q app.zip -d "${APP_ROOT}/" || [ $? -eq 1 ]; \
    rm -f app.zip; \
    test -f "${APP_ROOT}/public/index.php"; \
    test -f "${APP_ROOT}/database/install.sql"; \
    apk del .build-deps

# 补全 zip 中不包含的空目录（运行时 / 上传目录）
RUN set -eux; \
    mkdir -p \
      "${APP_ROOT}/runtime/cache" \
      "${APP_ROOT}/runtime/log" \
      "${APP_ROOT}/runtime/session" \
      "${APP_ROOT}/runtime/temp" \
      "${APP_ROOT}/public/storage/uploads"; \
    chown -R www-data:www-data "${APP_ROOT}"; \
    chmod 0755 "${APP_ROOT}"

# 配置
COPY nginx.conf /etc/nginx/nginx.conf
COPY php/php.ini /usr/local/etc/php/conf.d/zz-lzdh.ini
COPY php/www.conf /usr/local/etc/php-fpm.d/zz-lzdh.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY bootstrap.php /usr/local/lib/lzdh/bootstrap.php
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1

WORKDIR ${APP_ROOT}

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["run"]
