#!/bin/bash

VERSION="v251201"
REPO="qiankong/lzdh-app"
# 你的源码地址
SRC_URL="https://shop.lovestu.com/uploads/20251201/db311306755d314390abf39c123a39d9.zip"

echo ">>> 开始构建镜像: $REPO:$VERSION"
docker build \
  --build-arg APP_VERSION=$VERSION \
  --build-arg SOURCE_URL=$SRC_URL \
  -t $REPO:$VERSION \
  -t $REPO:latest \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo ">>> 构建完成！"
    echo ">>> 镜像标签:"
    echo "    - $REPO:$VERSION"
    echo "    - $REPO:latest"
    echo ""
    echo ">>> 推送镜像到 Docker Hub (可选):"
    echo "    docker push $REPO:$VERSION"
    echo "    docker push $REPO:latest"
else
    echo ""
    echo ">>> 构建失败！"
    exit 1
fi
