#!/bin/bash
set -euo pipefail

# ================= 默认值 =================
DEFAULT_VERSION="v1.0.2"
DEFAULT_REPO="qiankong/lzdh-app"
DEFAULT_URL="https://bit.bravexist.cn/2026/09/lzdh-plus-1.0.2.zip"
# ==========================================

read -rp "版本号 [${DEFAULT_VERSION}]: " INPUT_VERSION
VERSION="${INPUT_VERSION:-$DEFAULT_VERSION}"

read -rp "镜像名 [${DEFAULT_REPO}]: " INPUT_REPO
REPO="${INPUT_REPO:-$DEFAULT_REPO}"

read -rp "源码URL [默认预设]: " INPUT_URL
SRC_URL="${INPUT_URL:-$DEFAULT_URL}"

echo ""
echo "=========================================="
echo "  构建: ${REPO}:${VERSION}"
echo "  源码: ${SRC_URL}"
echo "=========================================="
echo ""

docker build \
  --build-arg APP_VERSION="${VERSION}" \
  --build-arg SOURCE_URL="${SRC_URL}" \
  -t "${REPO}:${VERSION}" \
  -t "${REPO}:latest" \
  .

echo ""
echo "✅ 构建成功！"
echo ""
echo "快速测试:"
echo "  docker run --rm -p 8080:80 ${REPO}:${VERSION} run"
echo ""
echo "推送到 Docker Hub:"
echo "  docker push ${REPO}:${VERSION}"
echo "  docker push ${REPO}:latest"
