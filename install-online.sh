#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${STEP_SYSTEM_REPO:-johIanse/bsweb}"
REF="${STEP_SYSTEM_REF:-main}"
INSTALL_DIR="${STEP_SYSTEM_DIR:-/opt/step-system}"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz"

info(){ printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
success(){ printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
err(){ printf '\033[1;31m[ERR]\033[0m %s\n' "$*" >&2; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { err "缺少命令：$1"; exit 1; }; }

if [[ "${EUID}" -ne 0 ]]; then
  err "请用 root 执行，例如：curl -fsSL https://raw.githubusercontent.com/${REPO}/${REF}/install-online.sh | sudo bash"
  exit 1
fi

need_cmd curl
need_cmd tar
need_cmd mktemp

TMP_DIR="$(mktemp -d)"
cleanup(){ rm -rf "$TMP_DIR"; }
trap cleanup EXIT

info "下载安装包：${ARCHIVE_URL}"
curl -fL --retry 3 --connect-timeout 15 "$ARCHIVE_URL" -o "$TMP_DIR/source.tar.gz"

tar -xzf "$TMP_DIR/source.tar.gz" -C "$TMP_DIR"
SRC_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
[[ -n "$SRC_DIR" && -d "$SRC_DIR" ]] || { err "解压失败，未找到源码目录"; exit 1; }

if [[ -d "$INSTALL_DIR" ]]; then
  BACKUP_DIR="${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
  info "检测到已有安装目录，备份到：${BACKUP_DIR}"
  cp -a "$INSTALL_DIR" "$BACKUP_DIR"
  [[ -f "$INSTALL_DIR/.env" ]] && cp -a "$INSTALL_DIR/.env" "$SRC_DIR/.env"
  [[ -f "$INSTALL_DIR/config/database.php" ]] && mkdir -p "$SRC_DIR/config" && cp -a "$INSTALL_DIR/config/database.php" "$SRC_DIR/config/database.php"
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
rm -rf "$INSTALL_DIR"
cp -a "$SRC_DIR" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/install.sh" || true

success "源码已准备到：${INSTALL_DIR}"
cd "$INSTALL_DIR"

if [[ "$#" -gt 0 ]]; then
  info "执行安装脚本参数：$*"
  exec bash install.sh "$@"
fi

info "默认进入 Docker 单容器安装/升级模式。你也可以传参覆盖，例如 --docker-repair 或 --reset-admin。"
exec bash install.sh --single
