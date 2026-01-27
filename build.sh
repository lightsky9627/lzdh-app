#!/bin/bash
VERSION="v251201"
REPO="qiankong/lzdh-app"
# 你的源码地址
SRC_URL="https://shop.lovestu.com/uploads/20251201/db311306755d314390abf39c123a39d9.zip"

# 检测当前机器架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_SUFFIX="amd64"
        PLATFORM="linux/amd64"
        ;;
    aarch64|arm64)
        ARCH_SUFFIX="arm64"
        PLATFORM="linux/arm64"
        ;;
    *)
        echo ">>> 不支持的架构: $ARCH"
        exit 1
        ;;
esac

echo ">>> 当前架构: $ARCH ($ARCH_SUFFIX)"
echo ">>> 开始构建镜像: $REPO:$VERSION-$ARCH_SUFFIX"
echo ""

# 构建镜像（带架构后缀）
docker build \
  --build-arg APP_VERSION=$VERSION \
  --build-arg SOURCE_URL=$SRC_URL \
  -t $REPO:$VERSION-$ARCH_SUFFIX \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo ">>> 构建完成！"
    echo "=========================================="
    echo ""
    echo ">>> 本地镜像标签:"
    echo "    - $REPO:$VERSION-$ARCH_SUFFIX"
    echo ""
    echo ">>> 测试镜像:"
    echo "    docker run --rm $REPO:$VERSION-$ARCH_SUFFIX <测试命令>"
    echo ""
    echo ">>> 推送当前架构镜像:"
    echo "    docker push $REPO:$VERSION-$ARCH_SUFFIX"
    echo ""
    echo "=========================================="
    echo ">>> 在所有架构机器上构建并推送后，执行以下命令合并："
    echo "=========================================="
    echo ""
    echo "# 创建并推送版本号标签的 manifest"
    echo "docker manifest create $REPO:$VERSION \\"
    echo "  $REPO:$VERSION-amd64 \\"
    echo "  $REPO:$VERSION-arm64"
    echo ""
    echo "docker manifest push $REPO:$VERSION"
    echo ""
    echo "# 创建并推送 latest 标签的 manifest"
    echo "docker manifest create $REPO:latest \\"
    echo "  $REPO:$VERSION-amd64 \\"
    echo "  $REPO:$VERSION-arm64"
    echo ""
    echo "docker manifest push $REPO:latest"
    echo ""
    echo "=========================================="
else
    echo ""
    echo ">>> 构建失败！"
    exit 1
fi
