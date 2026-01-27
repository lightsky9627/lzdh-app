# 粒子导航 (lzdh-app) Docker 版
[粒子导航](https://lzdh.lovestu.com/)是一款导航站主题，但是[官方文档[(https://www.yuque.com/applek/lzdh/wm3uiakuq4b1bob2)并没有给出 Docker版本部署手册。
这是一个基于 **Alpine Linux** 构建的粒子导航单镜像版本。为了简化部署，该镜像内部集成了 **Nginx 1.24** 和 **PHP 8.0-FPM**，实现了一键式开箱即用。

## 🚀 快速开始

如果你只想运行该导航系统，只需下载项目中的 `docker-compose.yaml` 文件，然后在同目录下运行：

```bash
docker-compose up -d

```

* **访问地址**：`http://ip`
* **数据库**：自动启动 MySQL 8.0 容器。
* **持久化**：数据库数据保存在当前目录生成的 `mysql_data` 卷中。

---

## 🛠️ 构建自己的镜像

如果你需要更新源码版本或更换仓库地址，可以按照以下步骤重新构建镜像：

### 1. 修改构建脚本

编辑 `build.sh`，根据需要修改 `VERSION`（版本号）和 `SRC_URL`（粒子导航源码下载地址）。

```bash
VERSION="v251201"
REPO="你的用户名/lzdh-app"
SRC_URL="https://源码下载直连地址.zip"

```

### 2. 执行构建

确保脚本具有可执行权限并运行：

```bash
chmod +x build.sh
./build.sh

```

构建成功后，脚本会自动生成两个标签：`latest` 和指定的版本号（如 `v251201`）。

---

## 📂 文件结构说明

| 文件 | 说明 |
| --- | --- |
| **Dockerfile** | 基于 `php:8.0-fpm-alpine`，包含 Nginx 安装及源码解压逻辑。 |
| **build.sh** | 一键构建脚本，支持自定义版本和源码地址。 |
| **docker-compose.yaml** | 编排文件，一键启动 App (Nginx+PHP) 与 MySQL 容器。 |
| **nginx.conf** | 预设好的 Nginx 配置，已处理 PHP 转发。 |
| **start.sh** | 容器启动入口脚本，确保 PHP 和 Nginx 同时运行。 |

---

## 📝 注意事项

* **环境依赖**：构建环境需已安装 Docker 和 Docker Compose。
* **基础镜像**：本项目严格使用 Alpine 版本基础镜像，以确保存储占用最小化（镜像大小约 100MB+）。
* **源码更新**：本方案将源码直接打包入镜像。如需更新应用代码，请修改 `build.sh` 中的 `SRC_URL` 后重新执行构建并重启 Compose。
