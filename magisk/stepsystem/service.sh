#!/system/bin/sh
MODDIR=${0%/*}
BASE=/data/adb/stepsystem
WEB=$MODDIR/web
LOGDIR=$BASE/logs
RUNDIR=$BASE/run
DATADIR=$BASE/data
PORT=${STEP_SYSTEM_PORT:-8058}
mkdir -p "$LOGDIR" "$RUNDIR" "$DATADIR" "$WEB/storage"
LOG=$LOGDIR/service.log
PIDFILE=$RUNDIR/php.pid

log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
find_php(){
  for p in \
    "$MODDIR/php/bin/php" \
    "$MODDIR/php/php" \
    /data/data/com.termux/files/usr/bin/php \
    /system/bin/php \
    /system/xbin/php; do
    [ -x "$p" ] && echo "$p" && return 0
  done
  return 1
}

sleep 15
PHP_BIN=$(find_php || true)
if [ -z "$PHP_BIN" ]; then
  log "ERROR: embedded php runtime not found in module"
  exit 0
fi

export TERMUX_PREFIX="$MODDIR/php"
export PREFIX="$MODDIR/php"
export LD_LIBRARY_PATH="$MODDIR/php/lib:$MODDIR/php/lib/php:$MODDIR/php/libexec:${LD_LIBRARY_PATH:-}"
export PATH="$MODDIR/php/bin:$MODDIR/php/libexec:$PATH"
export PHPRC="$MODDIR/php/lib"

if "$PHP_BIN" -m 2>/dev/null | grep -qi '^pdo_sqlite$'; then
  log "embedded pdo_sqlite OK"
else
  log "ERROR: embedded php exists but pdo_sqlite is missing"
  "$PHP_BIN" -m >> "$LOG" 2>&1 || true
  exit 0
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  log "already running pid=$(cat "$PIDFILE")"
  exit 0
fi

export APP_ENV=magisk
export APP_DEBUG=0
export APP_URL="http://127.0.0.1:$PORT"
export DB_DRIVER=sqlite
export DB_PATH="$DATADIR/step-system.sqlite"
export NODE_PATH="$WEB/node_modules"
export TZ=Asia/Shanghai

init_default_admin(){
  "$PHP_BIN" -r '
require "config/bootstrap.php";
require "app/Core/Database.php";
use StepSystem\Core\Database;
$p = Database::pdo();
$s = $p->query("SELECT COUNT(*) FROM users WHERE role=".$p->quote("admin"));
if ((int)$s->fetchColumn() === 0) {
  $p->prepare("INSERT INTO users(username,password,role,status,expires_at,created_at) VALUES(?,?,?,?,?,?)")
    ->execute(["admin", password_hash("admin", PASSWORD_DEFAULT), "admin", 1, null, date("Y-m-d H:i:s")]);
  echo "DEFAULT_ADMIN_CREATED\n";
}
' >> "$LOG" 2>&1 || log "WARN: default admin init failed"
}

cd "$WEB" || exit 0
init_default_admin
log "starting Step System on 127.0.0.1:$PORT with $PHP_BIN"
nohup "$PHP_BIN" -S "127.0.0.1:$PORT" -t public >> "$LOG" 2>&1 &
echo $! > "$PIDFILE"
log "started pid=$(cat "$PIDFILE")"
