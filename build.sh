#!/bin/bash

# ================= 配置默认值 =================
DEFAULT_VERSION="v251201"
DEFAULT_REPO="qiankong/lzdh-app"
DEFAULT_URL="https://shop.lovestu.com/uploads/20251201/db311306755d314390abf39c123a39d9.zip"
# ============================================

# 1. 获取版本号 (支持回车使用默认值)
read -p "请输入版本号 [默认: $DEFAULT_VERSION]: " INPUT_VERSION
VERSION=${INPUT_VERSION:-$DEFAULT_VERSION}

# 2. 获取镜像命名空间 (支持回车使用默认值)
read -p "请输入镜像名称 [默认: $DEFAULT_REPO]: " INPUT_REPO
REPO=${INPUT_REPO:-$DEFAULT_REPO}

# 3. 获取源码地址 (通常太长，一般直接回车用默认的)
read -p "请输入源码URL [默认: 脚本内预设地址]: " INPUT_URL
SRC_URL=${INPUT_URL:-$DEFAULT_URL}

echo ""
echo "----------------------------------------"
echo "正在构建: $REPO:$VERSION"
echo "源码地址: $SRC_URL"
echo "----------------------------------------"
echo ""

# 执行构建 (使用标准 docker build，自动适配你当前的本机架构)
docker build \
  --build-arg APP_VERSION="$VERSION" \
  --build-arg SOURCE_URL="$SRC_URL" \
  -t "$REPO:$VERSION" \
  -t "$REPO:latest" \
  .

# 检查结果
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 构建成功！"
    echo "你可以通过以下命令运行测试："
    echo "docker run -d -p 8080:80 $REPO:$VERSION"
else
    echo ""
    echo "❌ 构建失败，请检查上方报错信息。"
    exit 1
fi
