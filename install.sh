#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# 步数系统 一键安装 / 修复脚本
# - Docker 一键安装/修复（推荐）
# - 宝塔/PHP 环境检测安装
# - 后台管理员重置
# ============================================================

APP_NAME="步数系统"
SERVICE_SLUG="step-system"
APP_SERVICE="step-system"
MYSQL_SERVICE="step-mysql"
SINGLE_SERVICE="step-system-single"
SINGLE_SLUG="step-single"
DEFAULT_PORT="8088"
DEFAULT_DOMAIN="服务器IP"
DEFAULT_INSTALL_DIR="/www/wwwroot/step-system"
DEFAULT_DB_NAME="step_system"
DEFAULT_DB_USER="step_user"
DEFAULT_ADMIN_USER="admin"
DEFAULT_PHP_EXTS=(pdo pdo_mysql mysqli curl mbstring openssl json fileinfo session iconv)
NODE_PACKAGES=(got@11 tough-cookie iconv-lite global-agent hpagent)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_ADMIN_USER=""
CLI_ADMIN_PASS=""

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

line(){ printf '%s\n' "${DIM}────────────────────────────────────────${NC}"; }
section(){ echo; echo "${BOLD}${BLUE}▶ $*${NC}"; line; }
info(){ echo "${BLUE}ℹ${NC} $*"; }
success(){ echo "${GREEN}✓${NC} $*"; }
warn(){ echo "${YELLOW}!${NC} $*"; }
err(){ echo "${RED}✗ $*${NC}" >&2; }
kv(){ printf '  %-14s %s\n' "$1" "$2"; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }
need_root(){ [[ "${EUID}" -eq 0 ]] || { err "请用 root 执行：sudo bash install.sh"; exit 1; }; }
ask(){ local p="$1" d="${2:-}" a; if [[ -n "$d" ]]; then read -r -p "$p [$d]: " a || true; echo "${a:-$d}"; else read -r -p "$p: " a || true; echo "$a"; fi; }
confirm(){ local p="$1" d="${2:-N}" a; read -r -p "$p [$d]: " a || true; a="${a:-$d}"; [[ "$a" =~ ^[Yy是]$ ]]; }
rand_str(){ LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-32}" || true; }

banner(){
  [[ -n "${TERM:-}" && -t 1 ]] && clear || true
  cat <<EOF
${CYAN}${BOLD}
========================================
           步数系统安装器
========================================
${NC}${BOLD}${APP_NAME} 一键配置脚本${NC}
路径：${SCRIPT_DIR}
EOF
  line
}

pkg_install(){
  local packages=("$@")
  if has_cmd apt-get; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y "${packages[@]}"
  elif has_cmd yum; then
    yum install -y "${packages[@]}"
  elif has_cmd dnf; then
    dnf install -y "${packages[@]}"
  else
    err "未识别包管理器，请手动安装：${packages[*]}"
    return 1
  fi
}

ensure_basic_tools(){
  local missing=()
  for c in curl sed grep awk tar gzip; do has_cmd "$c" || missing+=("$c"); done
  (( ${#missing[@]} == 0 )) && return 0
  section "安装基础工具"
  pkg_install curl sed grep gawk tar gzip ca-certificates || true
}

env_get(){
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,"",$0); v=$0} END{if(v!="") print v}' "$file" 2>/dev/null || true
}

port_in_use(){
  local port="$1"
  if has_cmd ss; then ss -lnt | awk '{print $4}' | grep -Eq "[:.]${port}$"; elif has_cmd netstat; then netstat -lnt | awk '{print $4}' | grep -Eq "[:.]${port}$"; else return 1; fi
}

open_firewall_port(){
  local port="$1"
  section "防火墙提示"
  if has_cmd firewall-cmd && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --add-port="${port}/tcp" || true
    firewall-cmd --reload || true
    success "firewalld 已放行 ${port}/tcp"
  elif has_cmd ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${port}/tcp" || true
    success "ufw 已放行 ${port}/tcp"
  else
    warn "未检测到启用的 firewalld/ufw。若外网打不开，请检查 NAS 防火墙、路由器端口映射、安全组/宝塔防火墙。"
  fi
}

ensure_docker(){
  section "检查 Docker 环境"
  if has_cmd docker; then
    success "$(docker --version)"
  else
    warn "未检测到 Docker，尝试安装"
    if has_cmd apt-get; then pkg_install docker.io; else pkg_install docker; fi
    systemctl enable --now docker 2>/dev/null || true
  fi

  if docker compose version >/dev/null 2>&1; then
    success "$(docker compose version)"
  elif has_cmd docker-compose; then
    success "$(docker-compose --version)"
  else
    warn "未检测到 Docker Compose，尝试安装"
    if has_cmd apt-get; then pkg_install docker-compose-plugin || pkg_install docker-compose; else pkg_install docker-compose-plugin || pkg_install docker-compose; fi
  fi
}

compose_cmd(){
  if docker compose version >/dev/null 2>&1; then docker compose -p "$SERVICE_SLUG" "$@"; else docker-compose -p "$SERVICE_SLUG" "$@"; fi
}

compose_single_cmd(){
  if docker compose version >/dev/null 2>&1; then docker compose -p "$SINGLE_SLUG" -f docker-compose.single.yml "$@"; else docker-compose -p "$SINGLE_SLUG" -f docker-compose.single.yml "$@"; fi
}

compose_port_current(){
  [[ -f "$SCRIPT_DIR/docker-compose.yml" ]] || return 0
  awk 'match($0, /"[0-9]+:80"/) {s=substr($0,RSTART+1,RLENGTH-2); split(s,a,":"); print a[1]; exit}' "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
}

patch_compose_port(){
  local port="$1"
  [[ -f "$SCRIPT_DIR/docker-compose.yml" ]] || { err "未找到 docker-compose.yml"; exit 1; }
  sed -i -E "s/\"[0-9]+:80\"/\"${port}:80\"/" "$SCRIPT_DIR/docker-compose.yml"
}

public_host_default(){
  local app_url host
  app_url="$(env_get "$SCRIPT_DIR/.env" APP_URL)"
  host="${app_url#http://}"; host="${host#https://}"; host="${host%%/*}"; host="${host%%:*}"
  [[ -n "$host" && "$host" != "localhost" ]] && echo "$host" || echo "$DEFAULT_DOMAIN"
}

write_env_file_preserve(){
  local port="$1"
  local env_file="$SCRIPT_DIR/.env"
  local old_root old_token old_proxy
  old_root="$(env_get "$env_file" MYSQL_ROOT_PASSWORD)"
  old_token="$(env_get "$env_file" INSTALL_TOKEN)"
  old_proxy="$(env_get "$env_file" STEP_PROXY_API_URL)"
  [[ -z "$old_root" ]] && old_root="$(rand_str 32)"
  [[ -z "$old_token" ]] && old_token="$(rand_str 40)"
  [[ -f "$env_file" ]] && cp -a "$env_file" "$env_file.bak.$(date +%Y%m%d%H%M%S)"
  cat > "$env_file" <<EOF_ENV
APP_ENV=production
APP_DEBUG=0
APP_URL=http://localhost:${port}

DB_HOST=${MYSQL_SERVICE}
DB_NAME=${DEFAULT_DB_NAME}
DB_USER=root
DB_PASS=${old_root}
MYSQL_ROOT_PASSWORD=${old_root}

INSTALL_TOKEN=${old_token}
STEP_PROXY_API_URL=${old_proxy}
EOF_ENV
  chmod 600 "$env_file" || true
  success "已修复 .env（保留原 MySQL 密码和安装 token）"
}

write_docker_database_config(){
  local root_pass="$1"
  mkdir -p "$SCRIPT_DIR/config"
  cat > "$SCRIPT_DIR/config/database.php" <<EOF_PHP
<?php
return array (
  'host' => '${MYSQL_SERVICE}',
  'name' => '${DEFAULT_DB_NAME}',
  'user' => 'root',
  'pass' => '${root_pass}',
);
EOF_PHP
  chmod 640 "$SCRIPT_DIR/config/database.php" || true
  success "已写入 Docker 数据库配置 config/database.php"
}

backup_old_database_config(){
  if [[ -f "$SCRIPT_DIR/config/database.php" ]]; then
    mkdir -p "$SCRIPT_DIR/config/backup"
    cp -a "$SCRIPT_DIR/config/database.php" "$SCRIPT_DIR/config/backup/database.php.bak.$(date +%Y%m%d%H%M%S)"
    success "已备份旧 config/database.php"
  fi
}

wait_mysql_container(){
  local pass="$1" i
  info "等待 MySQL 就绪..."
  for i in $(seq 1 60); do
    if docker exec -e MYSQL_PWD="$pass" "$MYSQL_SERVICE" mysql -uroot -e "SELECT 1" >/dev/null 2>&1; then
      success "MySQL 已就绪，root 密码验证通过"
      return 0
    fi
    # 容器还在初始化时稍等；如果只是密码不对，后面会统一处理
    sleep 1
  done
  warn "MySQL 可用性/密码验证失败：可能是旧数据卷里的 root 密码和 .env 不一致。"
  return 1
}

reset_mysql_volume(){
  local port="$1"
  warn "检测到 MySQL 旧数据卷密码和 .env 不一致，自动重置 Docker MySQL 数据卷。"
  warn "注意：这会清空当前 Docker MySQL 里的旧数据；一键新安装/修复场景默认执行。"
  cd "$SCRIPT_DIR"
  compose_cmd down || true
  docker volume rm "${SERVICE_SLUG}_mysql_data" 2>/dev/null || docker volume rm "步数_mysql_data" 2>/dev/null || true
  success "旧 MySQL 数据卷已删除或不存在"
  patch_compose_port "$port"
  compose_cmd up -d --build
  compose_cmd ps
}

ensure_mysql_remote_root(){
  local pass="$1"
  info "修复 MySQL root@% 远程连接权限..."
  docker exec -e MYSQL_PWD="$pass" "$MYSQL_SERVICE" mysql -uroot -e "
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${pass}';
ALTER USER 'root'@'%' IDENTIFIED BY '${pass}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS ${DEFAULT_DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
"
  success "MySQL 远程连接权限已修复"
}

init_admin_docker_with_values(){
  local root_pass="$1" admin_user="$2" admin_pass="$3"
  [[ -n "$admin_user" && -n "$admin_pass" ]] || { warn "管理员账号或密码为空，跳过初始化"; return 1; }
  (( ${#admin_pass} >= 6 )) || { warn "管理员密码至少 6 位"; return 1; }

  write_docker_database_config "$root_pass"
  info "初始化数据表并重置管理员..."
  if docker exec \
    -e STEP_ADMIN_USER="$admin_user" \
    -e STEP_ADMIN_PASS="$admin_pass" \
    "$APP_SERVICE" php -r '
require "/var/www/html/config/bootstrap.php";
require "/var/www/html/app/Core/Database.php";
use StepSystem\Core\Database;
$p = Database::pdo();
Database::migrate($p);
$u = getenv("STEP_ADMIN_USER");
$pw = getenv("STEP_ADMIN_PASS");
$p->prepare("DELETE FROM users WHERE role=?")->execute(["admin"]);
$p->prepare("INSERT INTO users(username,password,role,status,expires_at,created_at) VALUES(?,?,?,?,?,?)")
  ->execute([$u, password_hash($pw, PASSWORD_DEFAULT), "admin", 1, null, date("Y-m-d H:i:s")]);
$s=$p->prepare("SELECT id,username,role,status FROM users WHERE username=?");
$s->execute([$u]);
$row=$s->fetch();
if(!$row){fwrite(STDERR,"admin insert failed\n"); exit(2);} 
echo "admin initialized: ".$row["username"]."\n";
'; then
    success "后台管理员已初始化：${admin_user}"
    return 0
  else
    err "后台管理员初始化失败，请检查上面的 PHP/PDO 错误"
    return 1
  fi
}

prompt_init_admin(){
  local root_pass="$1" admin_user admin_pass
  if [[ -n "$CLI_ADMIN_USER" || -n "$CLI_ADMIN_PASS" ]]; then
    admin_user="${CLI_ADMIN_USER:-$DEFAULT_ADMIN_USER}"
    admin_pass="$CLI_ADMIN_PASS"
  else
    confirm "是否直接初始化/重置后台管理员？这样可跳过网页安装" "Y" || return 0
    admin_user="$(ask "管理员账号" "$DEFAULT_ADMIN_USER")"
    read -r -s -p "管理员密码：" admin_pass || true; echo
  fi
  init_admin_docker_with_values "$root_pass" "$admin_user" "$admin_pass"
}


init_admin_single_with_values(){
  local admin_user="$1" admin_pass="$2"
  [[ -n "$admin_user" && -n "$admin_pass" ]] || { warn "管理员账号或密码为空，跳过初始化"; return 1; }
  (( ${#admin_pass} >= 6 )) || { warn "管理员密码至少 6 位"; return 1; }
  info "初始化单容器数据表并重置管理员..."
  if docker exec \
    -e STEP_ADMIN_USER="$admin_user" \
    -e STEP_ADMIN_PASS="$admin_pass" \
    "$SINGLE_SERVICE" php -r '
require "/var/www/html/config/bootstrap.php";
require "/var/www/html/app/Core/Database.php";
use StepSystem\Core\Database;
$p = Database::pdo();
Database::migrate($p);
$u = getenv("STEP_ADMIN_USER");
$pw = getenv("STEP_ADMIN_PASS");
$p->prepare("DELETE FROM users WHERE role=?")->execute(["admin"]);
$p->prepare("INSERT INTO users(username,password,role,status,expires_at,created_at) VALUES(?,?,?,?,?,?)")
  ->execute([$u, password_hash($pw, PASSWORD_DEFAULT), "admin", 1, null, date("Y-m-d H:i:s")]);
echo "admin initialized: ".$u."\n";
'; then
    success "后台管理员已初始化：${admin_user}"
  else
    err "后台管理员初始化失败"
    return 1
  fi
}

prompt_init_admin_single(){
  local admin_user admin_pass
  if [[ -n "$CLI_ADMIN_USER" || -n "$CLI_ADMIN_PASS" ]]; then
    admin_user="${CLI_ADMIN_USER:-$DEFAULT_ADMIN_USER}"
    admin_pass="$CLI_ADMIN_PASS"
  else
    confirm "是否直接初始化/重置后台管理员？这样可跳过网页安装" "Y" || return 0
    admin_user="$(ask "管理员账号" "$DEFAULT_ADMIN_USER")"
    read -r -s -p "管理员密码：" admin_pass || true; echo
  fi
  init_admin_single_with_values "$admin_user" "$admin_pass"
}

wait_single_container(){
  local i
  info "等待单容器站点就绪..."
  for i in $(seq 1 90); do
    if docker exec "$SINGLE_SERVICE" php -r 'require "/var/www/html/config/bootstrap.php"; require "/var/www/html/app/Core/Database.php"; StepSystem\Core\Database::pdo(); echo "ok\n";' >/dev/null 2>&1; then
      success "单容器数据库/PHP 已就绪"
      return 0
    fi
    sleep 1
  done
  err "单容器未在 90 秒内就绪，请查看日志：docker compose -p ${SINGLE_SLUG} -f docker-compose.single.yml logs -f"
  return 1
}

print_single_finish(){
  local port="$1"
  section "完成"
  echo "${GREEN}${BOLD}Docker 单容器安装/修复完成${NC}"
  echo
  kv "访问地址" "http://服务器IP:${port}/"
  kv "本机访问" "http://127.0.0.1:${port}/"
  echo
  echo "${BOLD}常用命令：${NC}"
  echo "  cd ${SCRIPT_DIR}"
  echo "  docker compose -p ${SINGLE_SLUG} -f docker-compose.single.yml ps"
  echo "  docker compose -p ${SINGLE_SLUG} -f docker-compose.single.yml logs -f ${SINGLE_SERVICE}"
  echo "  docker compose -p ${SINGLE_SLUG} -f docker-compose.single.yml restart"
}

docker_single_repair(){
  need_root
  banner
  ensure_basic_tools
  ensure_docker
  section "配置参数"
  local current_port port root_pass token old_proxy
  current_port="$(awk 'match($0, /"[0-9]+:80"/) {s=substr($0,RSTART+1,RLENGTH-2); split(s,a,":"); print a[1]; exit}' "$SCRIPT_DIR/docker-compose.single.yml" 2>/dev/null || true)"
  port="$(ask "宿主机访问端口" "${current_port:-$DEFAULT_PORT}")"
  root_pass="$(env_get "$SCRIPT_DIR/.env" MYSQL_ROOT_PASSWORD)"; [[ -z "$root_pass" ]] && root_pass="$(rand_str 32)"
  token="$(env_get "$SCRIPT_DIR/.env" INSTALL_TOKEN)"; [[ -z "$token" ]] && token="$(rand_str 40)"
  old_proxy="$(env_get "$SCRIPT_DIR/.env" STEP_PROXY_API_URL)"

  section "写入单容器配置"
  [[ -f "$SCRIPT_DIR/.env" ]] && cp -a "$SCRIPT_DIR/.env" "$SCRIPT_DIR/.env.bak.$(date +%Y%m%d%H%M%S)"
  cat > "$SCRIPT_DIR/.env" <<EOF_ENV
APP_ENV=production
APP_DEBUG=0
APP_URL=http://localhost:${port}

DB_HOST=127.0.0.1
DB_NAME=${DEFAULT_DB_NAME}
DB_USER=root
DB_PASS=${root_pass}
MYSQL_ROOT_PASSWORD=${root_pass}

INSTALL_TOKEN=${token}
STEP_PROXY_API_URL=${old_proxy}
EOF_ENV
  chmod 600 "$SCRIPT_DIR/.env" || true
  backup_old_database_config
  sed -i -E "s/\"[0-9]+:80\"/\"${port}:80\"/" "$SCRIPT_DIR/docker-compose.single.yml"

  section "启动单容器"
  cd "$SCRIPT_DIR"
  compose_single_cmd up -d --build
  compose_single_cmd ps
  wait_single_container
  prompt_init_admin_single
  open_firewall_port "$port"
  print_single_finish "$port"
}

print_docker_finish(){
  local port="$1" host="$2" token="$3"
  section "完成"
  echo "${GREEN}${BOLD}Docker 一键安装/修复完成${NC}"
  echo
  kv "访问地址" "http://服务器IP:${port}/"
  kv "本机访问" "http://127.0.0.1:${port}/"
  echo
  echo "${BOLD}数据库信息：${NC} 已自动写入 config/database.php，一般无需再打开安装向导。"
  kv "数据库地址" "$MYSQL_SERVICE"
  kv "数据库名" "$DEFAULT_DB_NAME"
  kv "数据库用户" "root"
  kv "数据库密码" "保存在 .env 的 MYSQL_ROOT_PASSWORD"
  echo
  echo "${BOLD}常用命令：${NC}"
  echo "  cd ${SCRIPT_DIR}"
  echo "  docker compose -p ${SERVICE_SLUG} ps"
  echo "  docker compose -p ${SERVICE_SLUG} logs -f ${APP_SERVICE}"
  echo "  docker compose -p ${SERVICE_SLUG} restart"
}

docker_one_click_repair(){
  need_root
  banner
  ensure_basic_tools
  ensure_docker

  section "配置参数"
  local current_port port host token root_pass
  current_port="$(compose_port_current)"
  port="$(ask "宿主机访问端口" "${current_port:-$DEFAULT_PORT}")"
  host="服务器IP"

  if port_in_use "$port"; then
    if docker ps --format '{{.Names}} {{.Ports}}' | grep -q "${APP_SERVICE} .*:${port}->80/tcp"; then
      success "端口 $port 正由 ${APP_SERVICE} 使用"
    else
      warn "端口 $port 已被其他进程占用"
      confirm "仍然继续？" "N" || exit 1
    fi
  fi

  section "写入配置"
  write_env_file_preserve "$port"
  root_pass="$(env_get "$SCRIPT_DIR/.env" MYSQL_ROOT_PASSWORD)"
  token="$(env_get "$SCRIPT_DIR/.env" INSTALL_TOKEN)"
  backup_old_database_config
  write_docker_database_config "$root_pass"
  patch_compose_port "$port"

  section "启动容器"
  cd "$SCRIPT_DIR"
  compose_cmd up -d --build
  compose_cmd ps

  section "初始化数据库"
  if ! wait_mysql_container "$root_pass"; then
    reset_mysql_volume "$port"
    wait_mysql_container "$root_pass" || { err "重置数据卷后 MySQL 仍无法验证密码"; exit 1; }
  fi
  ensure_mysql_remote_root "$root_pass"
  prompt_init_admin "$root_pass"

  open_firewall_port "$port"
  print_docker_finish "$port" "$host" "$token"
}

reset_admin_command(){
  need_root
  banner
  ensure_basic_tools
  ensure_docker
  cd "$SCRIPT_DIR"
  local root_pass admin_user admin_pass
  root_pass="$(env_get "$SCRIPT_DIR/.env" MYSQL_ROOT_PASSWORD)"
  [[ -n "$root_pass" ]] || { err "未在 .env 找到 MYSQL_ROOT_PASSWORD，请先运行：sudo bash install.sh --docker-repair"; exit 1; }
  compose_cmd up -d
  if ! wait_mysql_container "$root_pass"; then
    warn "当前 .env 密码无法登录 MySQL。若是新安装，请先运行：sudo bash install.sh --docker-repair 并选择重置 MySQL 数据卷。"
    exit 1
  fi
  ensure_mysql_remote_root "$root_pass"
  admin_user="${2:-}"
  admin_pass="${3:-}"
  [[ -z "$admin_user" ]] && admin_user="$(ask "管理员账号" "$DEFAULT_ADMIN_USER")"
  if [[ -z "$admin_pass" ]]; then read -r -s -p "管理员密码：" admin_pass || true; echo; fi
  init_admin_docker_with_values "$root_pass" "$admin_user" "$admin_pass"
  success "请打开站点首页使用管理员账号登录"
}

# ---------------- 宝塔/PHP 环境 ----------------
BT_DETECTED=0
check_bt(){
  if [[ -d /www/server/panel || -x /etc/init.d/bt || -x /usr/bin/bt ]]; then BT_DETECTED=1; success "检测到宝塔环境"; else BT_DETECTED=0; warn "未检测到宝塔环境，仍可按普通 PHP 站点继续"; fi
}
find_php_bin(){ if has_cmd php; then command -v php; else find /www/server/php -maxdepth 3 -type f -path '*/bin/php' 2>/dev/null | sort -V | tail -1 || true; fi; }
check_php_exts(){
  local php_bin="$1" loaded missing=()
  loaded="$($php_bin -m 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  for ext in "${DEFAULT_PHP_EXTS[@]}"; do
    if echo "$loaded" | grep -qx "$ext"; then echo "  ✓ $ext"; else echo "  ✗ $ext"; missing+=("$ext"); fi
  done
  (( ${#missing[@]} == 0 )) && success "PHP 扩展检测通过" || warn "缺少 PHP 扩展：${missing[*]}"
}
check_php_env(){
  local php_bin
  php_bin="$(find_php_bin)"
  [[ -n "$php_bin" && -x "$php_bin" ]] || { err "未检测到 PHP CLI"; return 1; }
  success "$($php_bin -v | head -1)"
  kv "PHP CLI" "$php_bin"
  check_php_exts "$php_bin"
  PHP_BIN_FOUND="$php_bin"
}
install_system_php_deps(){
  [[ "$BT_DETECTED" == "1" ]] && { warn "宝塔环境不自动改 PHP，请在宝塔 PHP 设置里安装扩展"; return 0; }
  confirm "是否自动安装缺失的 PHP/Node/MySQL 客户端依赖？" "Y" || return 0
  if has_cmd apt-get; then pkg_install php-cli php-mysql php-mbstring php-curl php-xml nodejs npm default-mysql-client cron || true
  elif has_cmd yum; then pkg_install php-cli php-mysqlnd php-mbstring php-curl php-json php-pdo nodejs npm mysql cronie || true
  elif has_cmd dnf; then pkg_install php-cli php-mysqlnd php-mbstring php-curl php-json php-pdo nodejs npm mysql cronie || true
  fi
}
copy_project(){ local dst="$1"; mkdir -p "$dst"; [[ "$SCRIPT_DIR" == "$dst" ]] && return 0; if has_cmd rsync; then rsync -a --delete --exclude '.git' --exclude 'node_modules' --exclude 'storage/*.log' "$SCRIPT_DIR/" "$dst/"; else cp -a "$SCRIPT_DIR/." "$dst/"; fi; }
ensure_node_deps(){
  local dir="$1"
  if ! has_cmd node || ! has_cmd npm; then warn "未检测到 Node/npm"; confirm "是否安装 nodejs npm？" "Y" && pkg_install nodejs npm || true; fi
  has_cmd npm && npm install --prefix "$dir" "${NODE_PACKAGES[@]}" || warn "npm 不存在，跳过 Node 依赖安装"
}
write_native_database_config(){
  local dst="$1" host="$2" name="$3" user="$4" pass="$5"
  mkdir -p "$dst/config"
  cat > "$dst/config/database.php" <<EOF_PHP
<?php
return array ('host'=>'${host}','name'=>'${name}','user'=>'${user}','pass'=>'${pass}');
EOF_PHP
}
fix_permissions(){ local dst="$1"; mkdir -p "$dst/storage" "$dst/config"; chmod -R u+rwX,go-rwx "$dst/storage" "$dst/config" || true; id www >/dev/null 2>&1 && chown -R www:www "$dst/storage" "$dst/config" || true; }
setup_cron_native(){ local dst="$1" php_bin="$2"; echo "* * * * * root cd ${dst} && ${php_bin} scheduler.php >> ${dst}/storage/step-scheduler.log 2>&1" > /etc/cron.d/step-system; chmod 0644 /etc/cron.d/step-system; success "已创建计划任务 /etc/cron.d/step-system"; }

install_bt_php(){
  need_root
  banner
  section "检查 PHP/宝塔环境"
  ensure_basic_tools
  check_bt
  check_php_env || true
  install_system_php_deps
  check_php_env || true
  section "配置参数"
  local install_dir port domain db_host db_name db_user db_pass token php_bin
  install_dir="$(ask "安装目录" "$DEFAULT_INSTALL_DIR")"
  port="$(ask "备用访问端口" "$DEFAULT_PORT")"
  domain="$(ask "域名或服务器 IP" "$DEFAULT_DOMAIN")"
  db_host="$(ask "数据库地址" "127.0.0.1")"
  db_name="$(ask "数据库名" "$DEFAULT_DB_NAME")"
  db_user="$(ask "数据库用户" "$DEFAULT_DB_USER")"
  db_pass="$(ask "数据库密码；留空自动生成" "")"; [[ -z "$db_pass" ]] && db_pass="$(rand_str 28)"
  token="$(rand_str 40)"
  php_bin="${PHP_BIN_FOUND:-$(find_php_bin)}"
  section "部署文件"
  copy_project "$install_dir"
  write_env_file_preserve "$port"
  write_native_database_config "$install_dir" "$db_host" "$db_name" "$db_user" "$db_pass"
  ensure_node_deps "$install_dir"
  fix_permissions "$install_dir"
  setup_cron_native "$install_dir" "$php_bin"
  open_firewall_port "$port"
  section "完成"
  kv "网站目录" "$install_dir"
  kv "运行目录" "$install_dir/public"
  kv "安装向导" "http://${domain}/install.php?token=${token}"
  warn "宝塔建站请把运行目录设为 /public，并确认 PHP 扩展齐全。"
}

show_status(){
  banner
  section "项目"
  kv "路径" "$SCRIPT_DIR"
  kv "Compose 项目" "$SERVICE_SLUG"
  section "Docker"
  has_cmd docker && success "$(docker --version)" || warn "未安装 Docker"
  if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]] && has_cmd docker; then cd "$SCRIPT_DIR" && compose_cmd ps 2>/dev/null || true; fi
  if [[ -f "$SCRIPT_DIR/docker-compose.single.yml" ]] && has_cmd docker; then cd "$SCRIPT_DIR" && compose_single_cmd ps 2>/dev/null || true; fi
  section "PHP / Node / MySQL 客户端"
  check_bt || true
  check_php_env || true
  has_cmd node && kv "Node" "$(node -v)" || kv "Node" "未安装"
  has_cmd npm && kv "npm" "$(npm -v)" || kv "npm" "未安装"
  has_cmd mysql && kv "mysql" "$(mysql --version)" || kv "mysql" "未安装"
  section "关键文件"
  ls -l "$SCRIPT_DIR/.env" "$SCRIPT_DIR/config/database.php" "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
}

uninstall_menu(){
  need_root
  banner
  warn "该操作只停止服务/计划任务，不删除数据库 volume 和项目文件。"
  confirm "删除 /etc/cron.d/step-system？" "N" && rm -f /etc/cron.d/step-system && success "已删除计划任务"
  if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]] && confirm "停止双容器 Docker Compose 服务？" "N"; then cd "$SCRIPT_DIR" && compose_cmd down && success "双容器服务已停止，volume 未删除"; fi
  if [[ -f "$SCRIPT_DIR/docker-compose.single.yml" ]] && confirm "停止单容器 Docker Compose 服务？" "N"; then cd "$SCRIPT_DIR" && compose_single_cmd down && success "单容器服务已停止，volume 未删除"; fi
}

parse_cli_options(){
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --admin-user)
        CLI_ADMIN_USER="${2:-}"; shift 2 ;;
      --admin-pass)
        CLI_ADMIN_PASS="${2:-}"; shift 2 ;;
      *)
        args+=("$1"); shift ;;
    esac
  done
  set -- "${args[@]}"
  ACTION="${1:-}"
}

main_menu(){
  banner
  cat <<EOF_MENU
${BOLD}请选择操作：${NC}
  ${GREEN}1)${NC} 宝塔/PHP 环境安装
  ${GREEN}2)${NC} Docker 双容器安装/修复（标准）
  ${GREEN}3)${NC} Docker 单容器安装/修复（简单）
  ${GREEN}4)${NC} 查看环境/服务状态
  ${GREEN}5)${NC} 停止/卸载服务（保留数据）
  ${GREEN}0)${NC} 退出
EOF_MENU
  echo
  local choice
  read -r -p "请输入选项 [0-5]: " choice || { warn "没有读取到输入，已退出"; exit 1; }
  case "${choice:-}" in
    1) install_bt_php ;;
    2) docker_one_click_repair ;;
    3) docker_single_repair ;;
    4) show_status ;;
    5) uninstall_menu ;;
    0) exit 0 ;;
    *) warn "无效选择"; sleep 1; main_menu ;;
  esac
}

parse_cli_options "$@"

case "${ACTION:-}" in
  --docker-repair|--docker|docker) docker_one_click_repair ;;
  --single|single|--docker-single) docker_single_repair ;;
  --reset-admin|reset-admin) reset_admin_command "$@" ;;
  --status|status) show_status ;;
  --help|-h|help)
    cat <<EOF_HELP
用法：
  sudo bash install.sh                 打开交互菜单
  sudo bash install.sh --docker-repair Docker 双容器安装/修复
  sudo bash install.sh --single        Docker 单容器安装/修复
  sudo bash install.sh --single --admin-user 账号 --admin-pass 密码
  sudo bash install.sh --reset-admin   重置后台管理员
  bash install.sh --status             查看状态
EOF_HELP
    ;;
  "") main_menu ;;
  *) err "未知参数：${ACTION}"; exit 1 ;;
esac
