# 步数系统

## 一键安装 / 一键修复

进入项目目录后执行：

```bash
chmod +x install.sh
sudo bash install.sh
```

菜单提供三种部署方式：

```text
1) 宝塔/PHP 环境安装
2) Docker 双容器安装/修复（标准）
3) Docker 单容器安装/修复（简单）
```

## 推荐选择

新手想省事：

```bash
sudo bash install.sh --single
```

标准 Docker 部署：

```bash
sudo bash install.sh --docker-repair
```

## 单容器模式

单容器模式把这些服务放到一个容器里：

- PHP / Apache
- MariaDB
- cron
- Node 依赖

优点是简单，只有一个容器、一个端口，不会遇到容器间数据库权限问题。

常用命令：

```bash
docker compose -p step-single -f docker-compose.single.yml ps
docker compose -p step-single -f docker-compose.single.yml logs -f step-system-single
docker compose -p step-single -f docker-compose.single.yml restart
```

## 双容器模式

双容器模式更标准：

- `step-system`：PHP / Apache / cron / Node
- `step-mysql`：MySQL

常用命令：

```bash
docker compose -p step-system ps
docker compose -p step-system logs -f step-system
docker compose -p step-system restart
```

## 重置后台管理员

```bash
sudo bash install.sh --reset-admin
```

按提示输入管理员账号和密码即可。

## GitHub 自动构建发布包

仓库已配置 GitHub Actions：

- 手动运行 `Build Release Packages` 可生成构建产物
- 推送 `v*` 标签会自动创建 GitHub Release

会生成：

- 干净源码包：`*-source.tar.gz` / `*-source.zip`
- 带 Node 模块依赖的完整包：`*-full.tar.gz` / `*-full.zip`
- Windows 自解压包：`*-source.exe`

注意：`.exe` 只是自解压源码包，不是 Windows 桌面程序；服务器部署仍推荐 Docker 单容器或双容器模式。
