#!/system/bin/sh
PIDFILE=/data/adb/stepsystem/run/php.pid
if [ -f "$PIDFILE" ]; then
  kill "$(cat "$PIDFILE")" 2>/dev/null || true
fi
