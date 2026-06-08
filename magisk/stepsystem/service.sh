#!/system/bin/sh
MODDIR=${0%/*}
BASE=/data/adb/stepsystem
WEB=$MODDIR/web
LOGDIR=$BASE/logs
RUNDIR=$BASE/run
DATADIR=$BASE/data
PORT=${STEP_SYSTEM_PORT:-8058}
LOG=$LOGDIR/service.log
PIDFILE=$RUNDIR/php.pid
SDLOG=/sdcard/步数管理-service.log

mkdir -p "$LOGDIR" "$RUNDIR" "$DATADIR" "$WEB/storage"

log(){
  line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$line" >> "$LOG"
  echo "$line" >> "$SDLOG" 2>/dev/null || true
  echo "$line" >&2
}

find_php(){
  log "php dir: $(ls -la "$MODDIR/php" 2>&1 | tr '
' '; ')"
  log "php bin dir: $(ls -la "$MODDIR/php/bin" 2>&1 | tr '
' '; ')"
  for p in \
    "$MODDIR/php/bin/php" \
    "$MODDIR/php/php" \
    /data/data/com.termux/files/usr/bin/php \
    /system/bin/php \
    /system/xbin/php; do
    if [ -f "$p" ]; then
      chmod 755 "$p" 2>/dev/null || true
      if [ -x "$p" ]; then
        echo "$p"
        return 0
      fi
      log "WARN: php candidate exists but is not executable: $p"
    fi
  done
  return 1
}

wait_boot(){
  i=0
  while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$i" -lt 60 ]; do
    sleep 2
    i=$((i+1))
  done
}

start_service(){
  wait_boot
  log "service start requested MODDIR=$MODDIR PORT=$PORT"
  log "module files: $(ls -la "$MODDIR" 2>&1 | tr '\n' '; ')"

  if [ ! -d "$WEB/public" ]; then
    log "ERROR: web/public not found: $WEB/public"
    return 1
  fi

  PHP_BIN=$(find_php || true)
  if [ -z "$PHP_BIN" ]; then
    log "ERROR: PHP runtime not found"
    return 1
  fi

  export TERMUX_PREFIX="$MODDIR/php"
  export PREFIX="$MODDIR/php"
  export LD_LIBRARY_PATH="$MODDIR/php/lib:$MODDIR/php/lib/php:$MODDIR/php/libexec:${LD_LIBRARY_PATH:-}"
  export PATH="$MODDIR/php/bin:$MODDIR/php/libexec:$PATH"
  export PHPRC="$MODDIR/php/lib"
  export PHP_INI_SCAN_DIR=
  export APP_ENV=magisk
  export APP_DEBUG=1
  export APP_URL="http://127.0.0.1:$PORT"
  export DB_DRIVER=sqlite
  export DB_PATH="$DATADIR/step-system.sqlite"
  export NODE_PATH="$WEB/node_modules"
  export TZ=Asia/Shanghai

  log "using PHP_BIN=$PHP_BIN"
  "$PHP_BIN" -v >> "$LOG" 2>&1 || log "ERROR: php -v failed"
  "$PHP_BIN" -v >> "$SDLOG" 2>&1 || true

  if ! "$PHP_BIN" -r 'echo "PHP_OK\n";' >> "$LOG" 2>&1; then
    log "ERROR: php cannot execute inline code"
    return 1
  fi

  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    log "already running pid=$(cat "$PIDFILE")"
  else
    cd "$WEB" || { log "ERROR: cd $WEB failed"; return 1; }
    log "starting PHP built-in server on 127.0.0.1:$PORT"
    nohup "$PHP_BIN" -d variables_order=EGPCS -S "127.0.0.1:$PORT" -t public >> "$LOG" 2>&1 &
    echo $! > "$PIDFILE"
    sleep 3
  fi

  if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    log "started pid=$(cat "$PIDFILE")"
  else
    log "ERROR: php server process is not running"
    return 1
  fi

  if command -v ss >/dev/null 2>&1; then
    ss -tunlp 2>/dev/null | grep ":$PORT" >> "$LOG" 2>&1 || log "WARN: ss cannot see port $PORT"
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tunlp 2>/dev/null | grep ":$PORT" >> "$LOG" 2>&1 || log "WARN: netstat cannot see port $PORT"
  fi

  log "open http://127.0.0.1:$PORT/"
}

start_service
