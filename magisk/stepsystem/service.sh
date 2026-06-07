#!/system/bin/sh
MODDIR=${0%/*}
BASE=/data/adb/stepsystem
WEB=$MODDIR/web
LOGDIR=$BASE/logs
RUNDIR=$BASE/run
DATADIR=$BASE/data
PORT=${STEP_SYSTEM_PORT:-8088}
mkdir -p "$LOGDIR" "$RUNDIR" "$DATADIR" "$WEB/storage"
LOG=$LOGDIR/service.log
PIDFILE=$RUNDIR/php.pid

log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
find_php(){
  for p in \
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
  log "ERROR: php runtime not found. Install Termux php or put executable at $MODDIR/php/php"
  exit 0
fi

if "$PHP_BIN" -m 2>/dev/null | grep -qi '^pdo_sqlite$'; then
  log "pdo_sqlite OK"
else
  log "ERROR: php found at $PHP_BIN but pdo_sqlite is missing"
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

cd "$WEB" || exit 0
log "starting Step System on 127.0.0.1:$PORT with $PHP_BIN"
nohup "$PHP_BIN" -S "127.0.0.1:$PORT" -t public >> "$LOG" 2>&1 &
echo $! > "$PIDFILE"
log "started pid=$(cat "$PIDFILE")"
