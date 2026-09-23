#!/bin/sh
# ==========================================================
# 粒子导航 Docker 入口脚本
#   1. 按 PUID/PGID 调整 www-data，修正 bind mount 的属主
#   2. 保证挂载目录结构完整并可写
#   3. 初始化数据库 / .env / install.lock
#   4. 前台启动 php-fpm + nginx
# ==========================================================
set -e

APP_ROOT="${APP_ROOT:-/var/www/html}"
BOOTSTRAP=/usr/local/lib/lzdh/bootstrap.php
PUID="${PUID:-82}"
PGID="${PGID:-82}"

log() { echo "[entrypoint] $*"; }

# ---------- 时区 ----------
if [ -n "${TZ}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    cp "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
fi

# ---------- 用户映射 ----------
# 宿主机 bind mount 会保留宿主机的 uid/gid，容器里的 www-data(82) 往往没有写权限。
# 这里把容器内 www-data 的 uid/gid 改成用户指定值（默认 82），从根源解决上传写不进去的问题。
CURRENT_UID="$(id -u www-data)"
CURRENT_GID="$(id -g www-data)"

if [ "${PGID}" != "${CURRENT_GID}" ]; then
    log "调整 www-data 组 GID: ${CURRENT_GID} -> ${PGID}"
    # 若目标 GID 已被占用，直接复用该组名
    if getent group "${PGID}" >/dev/null 2>&1; then
        EXIST_GROUP="$(getent group "${PGID}" | cut -d: -f1)"
        log "GID ${PGID} 已被组 ${EXIST_GROUP} 占用，www-data 加入该组"
        addgroup www-data "${EXIST_GROUP}" 2>/dev/null || true
    else
        groupmod -g "${PGID}" www-data 2>/dev/null || sed -i "s/^www-data:x:${CURRENT_GID}:/www-data:x:${PGID}:/" /etc/group
    fi
fi

if [ "${PUID}" != "${CURRENT_UID}" ]; then
    log "调整 www-data 用户 UID: ${CURRENT_UID} -> ${PUID}"
    usermod -u "${PUID}" www-data 2>/dev/null \
        || sed -i "s/^www-data:x:${CURRENT_UID}:[0-9]*:/www-data:x:${PUID}:${PGID}:/" /etc/passwd
fi

RUN_UID="$(id -u www-data)"
RUN_GID="$(id -g www-data)"
log "应用运行身份: www-data (${RUN_UID}:${RUN_GID})"

# ---------- 目录结构 ----------
# zip 包不含空目录；挂载空卷时同样需要重建，否则 PHP mkdir 会因父目录不可写而失败。
WRITABLE_DIRS="
${APP_ROOT}/runtime
${APP_ROOT}/runtime/cache
${APP_ROOT}/runtime/log
${APP_ROOT}/runtime/session
${APP_ROOT}/runtime/temp
${APP_ROOT}/runtime/temp/nginx_upload
${APP_ROOT}/runtime/storage
${APP_ROOT}/public/storage
${APP_ROOT}/public/storage/uploads
${APP_ROOT}/public/storage/uploads/avatar
/var/log/nginx
/var/log/php
/run/nginx
"

for dir in ${WRITABLE_DIRS}; do
    mkdir -p "${dir}"
done

# ---------- 权限修正 ----------
# 只处理需要写入的路径，避免每次启动 chown 整个源码目录（慢且无意义）。
# 先逐个修正刚创建的目录（root 创建），再对挂载根做递归检查。
for dir in ${WRITABLE_DIRS}; do
    owner="$(stat -c '%u:%g' "${dir}" 2>/dev/null || echo '')"
    if [ -n "${owner}" ] && [ "${owner}" != "${RUN_UID}:${RUN_GID}" ]; then
        chown "${RUN_UID}:${RUN_GID}" "${dir}" 2>/dev/null || true
    fi
    chmod u+rwX "${dir}" 2>/dev/null || true
done

# 递归修正：只在发现属主不匹配时执行，避免大量文件时启动变慢。
# FORCE_CHOWN=true 可强制全量修复（从旧版本迁移时好用）。
# 注意: BusyBox find 不支持 -uid/-gid，必须用 -user/-group
fix_perm_recursive() {
    target="$1"
    [ -d "${target}" ] || return 0
    if [ "${FORCE_CHOWN:-false}" = "true" ] \
        || [ -n "$(find "${target}" \( ! -user "${RUN_UID}" -o ! -group "${RUN_GID}" \) -print -quit 2>/dev/null)" ]; then
        log "修正属主(递归): ${target} -> ${RUN_UID}:${RUN_GID}"
        chown -R "${RUN_UID}:${RUN_GID}" "${target}" 2>/dev/null \
            || log "警告: 无法修改 ${target} 属主（只读挂载？）"
        chmod -R u+rwX "${target}" 2>/dev/null || true
    fi
}

fix_perm_recursive "${APP_ROOT}/runtime"
fix_perm_recursive "${APP_ROOT}/public/storage"
fix_perm_recursive /var/log/nginx
fix_perm_recursive /var/log/php

# .env / install.lock 由 PHP 写入，应用根目录必须对 www-data 可写
chown "${RUN_UID}:${RUN_GID}" "${APP_ROOT}" 2>/dev/null || true
[ -f "${APP_ROOT}/.env" ] && chown "${RUN_UID}:${RUN_GID}" "${APP_ROOT}/.env" 2>/dev/null || true

# 写入自检：上传失败最常见的原因就是这里
check_writable() {
    path="$1"
    if su-exec www-data test -w "${path}"; then
        return 0
    fi
    log "!!! 警告: ${path} 对 www-data(${RUN_UID}:${RUN_GID}) 不可写"
    log "!!! 当前属主: $(stat -c '%u:%g' "${path}")"
    log "!!! 修复方式 A: 宿主机执行 sudo chown -R ${RUN_UID}:${RUN_GID} <挂载目录>"
    log "!!! 修复方式 B: compose 中设置 PUID/PGID 为宿主机目录属主"
    return 1
}

check_writable "${APP_ROOT}/public/storage/uploads" || true
check_writable "${APP_ROOT}/runtime" || true
check_writable "${APP_ROOT}" || true

case "$1" in
    run)
        # ---------- 数据库初始化 ----------
        if [ "${SKIP_DB_INIT:-false}" != "true" ]; then
            php "${BOOTSTRAP}" install
            chown "${RUN_UID}:${RUN_GID}" "${APP_ROOT}/.env" "${APP_ROOT}/runtime/install.lock" 2>/dev/null || true
        else
            log "SKIP_DB_INIT=true，跳过数据库初始化"
        fi

        # ---------- 启动服务 ----------
        log "启动 php-fpm..."
        php-fpm -D

        i=0
        while [ $i -lt 40 ]; do
            [ -S /run/php-fpm.sock ] && break
            i=$((i + 1))
            sleep 0.25
        done
        [ -S /run/php-fpm.sock ] || log "警告: php-fpm socket 未就绪，继续启动 nginx"

        log "启动 nginx..."
        exec nginx -g 'daemon off;'
        ;;

    doctor)
        exec php "${BOOTSTRAP}" doctor
        ;;

    sync-env)
        exec php "${BOOTSTRAP}" sync-env
        ;;

    *)
        exec "$@"
        ;;
esac
