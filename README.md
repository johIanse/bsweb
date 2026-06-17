# 步数系统

## 安装 / 升级

### 一键安装 / 升级

复制下面命令到服务器执行即可，默认安装到 `/opt/step-system`，并启动 Docker 单容器版：

```bash
curl -fsSL https://raw.githubusercontent.com/johIanse/bsweb/main/install-online.sh | sudo bash
```

如果要指定安装目录：

```bash
curl -fsSL https://raw.githubusercontent.com/johIanse/bsweb/main/install-online.sh | sudo STEP_SYSTEM_DIR=/opt/step-system bash
```

常用参数可以按需要单独复制：

#### Docker 单容器安装/升级（默认）

适合新安装、升级，或想用最简单部署方式的情况。

```bash
curl -fsSL https://raw.githubusercontent.com/johIanse/bsweb/main/install-online.sh | sudo bash -s -- --single
```

安装完成后默认管理员为：

```text
账号：admin
密码：admin123
```

如果想一次安装并明确指定管理员账号密码，推荐直接复制下面这条：

```bash
curl -fsSL https://raw.githubusercontent.com/johIanse/bsweb/main/install-online.sh | sudo bash -s -- --single --admin-user admin --admin-pass admin123
```

#### Docker 双容器安装/修复

适合使用 PHP 容器 + MySQL 容器的标准 Docker 部署，或需要修复双容器环境时使用。

```bash
curl -fsSL https://raw.githubusercontent.com/johIanse/bsweb/main/install-online.sh | sudo bash -s -- --docker-repair
```

#### 重置后台管理员

忘记后台账号或密码时使用，只重置后台管理员，不重装系统。

```bash
curl -fsSL https://raw.githubusercontent.com/johIanse/bsweb/main/install-online.sh | sudo bash -s -- --reset-admin
```

也可以直接指定账号密码，避免交互输入：

```bash
curl -fsSL https://raw.githubusercontent.com/johIanse/bsweb/main/install-online.sh | sudo bash -s -- --reset-admin --admin-user admin --admin-pass admin123
```

一键脚本会自动下载 GitHub 最新源码；如果目标目录已存在，会先备份旧目录，并保留 `.env` 和 `config/database.php`。

### 手动安装 / 升级

如果不想使用在线脚本，也可以手动下载安装：

```bash
git clone https://github.com/johIanse/bsweb.git
cd bsweb
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

如果安装时提示：

```text
单容器未在 180 秒内就绪
```

请先看脚本自动打印的最近日志。也可以手动执行：

```bash
cd /opt/step-system
docker compose -p step-single -f docker-compose.single.yml ps
docker compose -p step-single -f docker-compose.single.yml logs --tail=200 step-system-single
curl -I --max-time 5 http://127.0.0.1:8088/ || true
```

常见原因：容器启动失败、端口被占用、MariaDB 初始化慢、`.env` 权限异常或旧数据目录不兼容。

如果看到：

```text
open /opt/step-system/.env: permission denied
```

说明 Docker Compose 当前用户无法读取 `.env`。可先执行：

```bash
cd /opt/step-system
sudo chown root:root .env
sudo chmod 644 .env
```

新版安装脚本会在执行 compose 前自动修复 `.env` 权限。

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

## 固定站点地址 / 授权回调地址

授权登录里的 `/yh` 回调地址默认会按当前访问域名自动生成。比如你用：

```text
http://example.com:8088
```

打开后台时，系统会显示：

```text
http://example.com:8088/yh
```

如果你不想自动识别，可以在项目 `.env` 里固定站点地址：

```env
APP_URL=http://你的域名或IP:8088
```

然后重启容器：

```bash
docker compose -p step-single -f docker-compose.single.yml restart
```

也可以使用兼容变量：

```env
STEP_PUBLIC_URL=http://你的域名或IP:8088
```

优先级：`APP_URL` > `STEP_PUBLIC_URL` > 当前访问域名自动识别。

## GitHub 自动构建发布包

仓库已配置 GitHub Actions：

- 手动运行 `Build Release Packages` 可生成构建产物
- 推送 `v*` 标签会自动创建 GitHub Release

会生成：

- 干净源码包：`*-source.tar.gz` / `*-source.zip`
- 带 Node 模块依赖的完整包：`*-full.tar.gz` / `*-full.zip`
- Windows 可运行启动包：`*-windows-runnable.zip` / `*-windows-runnable.exe`
- Windows 启动器：`Start-StepSystem.exe`
- Windows 停止器：`Stop-StepSystem.exe`

注意：Windows 可运行 exe 是 Docker 启动器，不是把 PHP/MariaDB 编译成单个桌面程序。使用前需要先安装并启动 Docker Desktop。双击 `Start-StepSystem.exe` 会自动启动单容器版并打开浏览器。

### Windows

GitHub Actions 会生成不依赖 Docker 的 Windows 单机版：

- `StepSystem-Portable.exe`
- `*-windows-portable.zip`
- `*-windows-portable.exe`

单机版内置 PHP Windows 运行时、SQLite 数据库支持和 Node 依赖。双击后会启动本地网站：

```text
http://127.0.0.1:8088/
```

默认后台账号：

```text
admin / admin
```

数据保存在：

```text
data/step-system.sqlite
```

注意：单机版适合本地 Windows 个人使用；服务器部署仍推荐 Docker 单容器或双容器。

## Android Magisk 模块

Release 会生成：

```text
step-system-版本-magisk.zip
```

这是 Android/Magisk 本地服务模块，安装后尝试在手机本机启动：

```text
http://127.0.0.1:8058/
```

默认后台账号：

```text
admin / admin
```

当前模块包内包含源码、Node 依赖和 Android arm64 PHP 运行时。

日志位置：

```text
/data/adb/stepsystem/logs/service.log
```

说明：Magisk 模块版适合已 Root 的 Android 设备。完全内置 Android PHP 运行时会继续完善。
