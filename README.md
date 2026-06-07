# 步数系统

## 一键安装 / 一键修复

进入项目目录后执行：

```bash
chmod +x install.sh
sudo bash install.sh
```

推荐直接选：

```text
2) Docker 一键安装/修复（推荐）
```

也可以非交互执行：

```bash
sudo bash install.sh --docker-repair
```

## 新版脚本特点

- 美化菜单和步骤分区
- 固定 Docker Compose 项目名为 `step-system`
- 修复中文目录导致的 `project name must not be empty`
- 保留已有 `.env` 里的 `MYSQL_ROOT_PASSWORD` 和 `INSTALL_TOKEN`
- 自动写入 Docker 版 `config/database.php`
- 自动修复 MySQL `root@%` 权限
- 可直接初始化/重置后台管理员
- 统一输出访问地址、数据库填写项和管理命令

## Docker 管理命令

在项目目录下执行：

```bash
docker compose -p step-system ps
docker compose -p step-system logs -f step-system
docker compose -p step-system restart
```

## 重置后台管理员

在项目目录下执行：

```bash
sudo bash install.sh --reset-admin
```

按提示输入管理员账号和密码即可。
