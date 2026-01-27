#!/bin/bash
VERSION="v251201"
REPO="qiankong/lzdh-app"
SRC_URL="https://shop.lovestu.com/uploads/20251201/db311306755d314390abf39c123a39d9.zip"

# 检测架构
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH_SUFFIX="amd64" ;;
    aarch64|arm64) ARCH_SUFFIX="arm64" ;;
    *)
        echo "不支持的架构: $ARCH"
        exit 1
        ;;
esac

echo "构建 $REPO:$VERSION-$ARCH_SUFFIX"

# 构建
docker build \
  --build-arg APP_VERSION=$VERSION \
  --build-arg SOURCE_URL=$SRC_URL \
  -t $REPO:$VERSION-$ARCH_SUFFIX \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "构建完成: $REPO:$VERSION-$ARCH_SUFFIX"
    echo ""
    echo "推送镜像:"
    echo "  docker push $REPO:$VERSION-$ARCH_SUFFIX"
    echo ""
    echo "两个架构都推送后，合并:"
    echo "  docker manifest create $REPO:$VERSION $REPO:$VERSION-amd64 $REPO:$VERSION-arm64"
    echo "  docker manifest push $REPO:$VERSION"
    echo "  docker manifest create $REPO:latest $REPO:$VERSION-amd64 $REPO:$VERSION-arm64"
    echo "  docker manifest push $REPO:latest"
else
    echo "构建失败"
    exit 1
fi
