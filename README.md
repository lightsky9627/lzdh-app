# 粒子导航 Docker 部署方案

## 项目简介

粒子导航的 Docker 容器化部署方案，包含：
- **lzdh-app**: Nginx + PHP 8.0 (Alpine) 单容器
- **mysql**: MySQL 8.0.44 数据库

## 快速开始

### 1. 构建镜像（开发者）

```bash
# 克隆仓库
git clone https://github.com/lightsky9627/lzdh-app.git
cd lzdh-app

# 赋予执行权限
chmod +x build.sh

# 构建镜像
./build.sh
```

### 2. 推送镜像到 Docker Hub（开发者）

```bash
# 登录 Docker Hub
docker login

# 推送镜像
docker push qiankong/lzdh-app:v251201
docker push qiankong/lzdh-app:latest
```

### 3. 使用已发布的镜像（用户）

用户只需下载 `docker-compose.yaml` 文件即可一键启动：

```bash
# 下载 docker-compose.yaml
wget https://raw.githubusercontent.com/lightsky9627/lzdh-app/main/docker-compose.yaml

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down

# 停止并删除数据卷
docker-compose down -v
```

### 4. 访问应用

浏览器打开：`http://localhost` 或 `http://your-server-ip`

## 目录结构

```
lzdh-app/
├── Dockerfile              # Docker 镜像构建文件
├── build.sh               # 镜像构建脚本
├── start.sh               # 容器启动脚本
├── nginx.conf             # Nginx 配置文件
├── docker-compose.yaml    # Docker Compose 编排文件
├── README.md              # 项目说明文档
├── html/                  # 应用源码目录（自动创建）
├── logs/                  # 日志目录（自动创建）
│   ├── nginx/            # Nginx 日志
│   └── php/              # PHP 日志
└── mysql/                 # MySQL 配置（可选）
    └── conf.d/           # MySQL 自定义配置
```

## 环境变量配置

### MySQL 配置

编辑 `docker-compose.yaml` 修改数据库配置：

```yaml
environment:
  MYSQL_ROOT_PASSWORD: your_root_password    # MySQL root 密码
  MYSQL_DATABASE: lzdh                       # 数据库名
  MYSQL_USER: lzdh                           # 数据库用户
  MYSQL_PASSWORD: your_password              # 数据库密码
```

### 应用配置

```yaml
environment:
  DB_HOST: mysql              # 数据库主机（容器名）
  DB_PORT: 3306              # 数据库端口
  DB_DATABASE: lzdh          # 数据库名
  DB_USERNAME: lzdh          # 数据库用户
  DB_PASSWORD: your_password # 数据库密码
```

## 端口映射

- **80**: Web 服务端口
- **3306**: MySQL 数据库端口（可选暴露）

如需修改端口，编辑 `docker-compose.yaml`：

```yaml
ports:
  - "8080:80"    # 将 Web 服务映射到 8080 端口
  - "3307:3306"  # 将 MySQL 映射到 3307 端口
```

## 数据持久化

项目使用 Docker 卷和主机挂载实现数据持久化：

- **mysql_data**: MySQL 数据卷（自动创建）
- **./html**: 应用源码（主机挂载）
- **./logs**: 日志文件（主机挂载）

## 常用命令

```bash
# 启动服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f lzdh-app
docker-compose logs -f mysql

# 重启服务
docker-compose restart

# 停止服务
docker-compose stop

# 删除服务（保留数据）
docker-compose down

# 删除服务和数据卷
docker-compose down -v

# 进入容器
docker exec -it lzdh-app sh
docker exec -it lzdh-mysql bash

# 更新镜像
docker-compose pull
docker-compose up -d
```

## 数据库导入

```bash
# 方式1: 使用 docker exec
docker exec -i lzdh-mysql mysql -ulzdh -plzdh_password lzdh < backup.sql

# 方式2: 进入容器导入
docker exec -it lzdh-mysql bash
mysql -ulzdh -plzdh_password lzdh < /path/to/backup.sql
```

## 数据库备份

```bash
# 备份数据库
docker exec lzdh-mysql mysqldump -ulzdh -plzdh_password lzdh > backup_$(date +%Y%m%d_%H%M%S).sql

# 备份所有数据库
docker exec lzdh-mysql mysqldump -uroot -plzdh_root_password --all-databases > all_databases.sql
```

## 技术栈

- **操作系统**: Alpine Linux 3.23.2
- **Web 服务器**: Nginx 1.24.0
- **PHP**: PHP 8.0 FPM (Alpine)
- **数据库**: MySQL 8.0.44
- **容器编排**: Docker Compose 3.8

## 健康检查

项目配置了健康检查机制：

- **lzdh-app**: 每 30 秒检查一次 HTTP 服务
- **mysql**: 每 10 秒检查一次数据库连接

## 故障排查

### 1. 容器无法启动

```bash
# 查看容器日志
docker-compose logs lzdh-app
docker-compose logs mysql

# 检查容器状态
docker-compose ps
```

### 2. 数据库连接失败

- 检查 MySQL 容器是否正常运行
- 确认数据库配置是否正确
- 检查网络连接：`docker network inspect lzdh-app_lzdh-network`

### 3. 权限问题

```bash
# 修复目录权限
sudo chown -R 82:82 ./html  # www-data 用户 UID/GID 在 Alpine 中是 82
```

### 4. 端口占用

```bash
# 检查端口占用
netstat -tuln | grep 80
netstat -tuln | grep 3306

# 修改 docker-compose.yaml 中的端口映射
```

## 安全建议

1. **修改默认密码**: 在生产环境中，务必修改 MySQL 默认密码
2. **限制端口暴露**: 不需要外部访问 MySQL 时，删除 `ports` 配置
3. **使用环境变量文件**: 敏感信息使用 `.env` 文件管理
4. **定期更新镜像**: 及时更新到最新版本以获取安全补丁
5. **配置防火墙**: 限制对外暴露的端口访问

## 更新日志

### v251201
- 初始版本
- 基于 PHP 8.0 FPM Alpine
- 集成 Nginx 1.24.0
- 使用 MySQL 8.0.44

## 许可证

本项目遵循原项目许可证。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

- GitHub: https://github.com/lightsky9627/lzdh-app
- 问题反馈: https://github.com/lightsky9627/lzdh-app/issues
