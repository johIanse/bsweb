#!/system/bin/sh
MODDIR=${0%/*}
case "$MODDIR" in
  /*) ;;
  *) MODDIR="$(cd "$MODDIR" 2>/dev/null && pwd)" ;;
esac
[ -n "$MODDIR" ] || MODDIR=/data/adb/modules/stepsystem
BASE=/data/adb/stepsystem
WEB=$MODDIR/web
LOGDIR=$BASE/logs
DATADIR=$BASE/data
TMPDIR_STEP=$BASE/tmp
SESSIONDIR=$BASE/sessions
PIDFILE=$BASE/run/scheduler.pid
LOG=$LOGDIR/scheduler.log
PHP_BIN=$MODDIR/php/bin/php
mkdir -p "$LOGDIR" "$BASE/run" "$DATADIR" "$TMPDIR_STEP" "$SESSIONDIR" "$WEB/storage"
chmod 755 "$BASE" "$LOGDIR" "$BASE/run" "$DATADIR" "$TMPDIR_STEP" "$SESSIONDIR" "$WEB/storage" 2>/dev/null || true

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] scheduler already running pid=$(cat "$PIDFILE")" >> "$LOG"
  exit 0
fi

(
  echo $$ > "$PIDFILE"
  export TERMUX_PREFIX="$MODDIR/php"
  export PREFIX="$MODDIR/php"
  export LD_LIBRARY_PATH="$MODDIR/php/lib:$MODDIR/php/lib/php:$MODDIR/php/libexec:${LD_LIBRARY_PATH:-}"
  export PATH="$MODDIR/php/bin:$MODDIR/php/libexec:$PATH"
  export PHPRC="$MODDIR/php/lib"
  export PHP_INI_SCAN_DIR=
  export APP_ENV=magisk
  export APP_DEBUG=1
  export APP_URL="http://127.0.0.1:8058"
  export DB_DRIVER=sqlite
  export DB_PATH="$DATADIR/step-system.sqlite"
  export NODE_PATH="$WEB/node_modules"
  export TMPDIR="$TMPDIR_STEP"
  export TEMP="$TMPDIR_STEP"
  export TMP="$TMPDIR_STEP"
  export TZ=Asia/Shanghai
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] scheduler daemon start MODDIR=$MODDIR"
  while true; do
    cd "$WEB" || exit 1
    "$PHP_BIN" \
      -d variables_order=EGPCS \
      -d sys_temp_dir="$TMPDIR_STEP" \
      -d session.save_path="$SESSIONDIR" \
      -d opcache.enable=0 \
      -d opcache.enable_cli=0 \
      scheduler.php >> "$LOG" 2>&1
    sleep 60
  done
) >> "$LOG" 2>&1 &
