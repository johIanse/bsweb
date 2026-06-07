# 飞牛 NAS 部署说明（安全版）

## 1. 准备目录
把整个项目放到飞牛目录，例如：

- `/vol1/docker/step-system`

## 2. 复制环境变量文件
在项目目录执行：

```bash
cp .env.example .env
```

然后编辑 `.env`，至少修改：

- `DB_PASS`
- `MYSQL_ROOT_PASSWORD`
- `INSTALL_TOKEN`

建议 `INSTALL_TOKEN` 用 32 位以上随机字符串。

## 3. 启动
```bash
docker compose --env-file .env up -d --build
```

## 4. 首次安装
浏览器访问：

- `http://飞牛IP:8088/install.php?token=你的INSTALL_TOKEN`

数据库参数填写：

- 主机：`step-mysql`
- 数据库：`step_system`
- 用户：`step_user`
- 密码：`.env` 里的 `DB_PASS`

管理员账号和密码请自行设置强密码。

## 5. 安装完成后
建议做这几件事：

1. 删除或重命名 `public/install.php`
2. 或至少把 `.env` 里的 `INSTALL_TOKEN` 改掉
3. 不要直接暴露公网，优先走飞牛反向代理 + 访问控制
4. 定期备份 MySQL 数据卷

## 6. 更新
```bash
docker compose --env-file .env up -d --build
```
