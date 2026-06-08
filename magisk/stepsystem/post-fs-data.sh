#!/system/bin/sh
MODDIR=${0%/*}
case "$MODDIR" in
  /*) ;;
  *) MODDIR="$(cd "$MODDIR" 2>/dev/null && pwd)" ;;
esac
[ -n "$MODDIR" ] || MODDIR=/data/adb/modules/stepsystem
LOG=/data/adb/stepsystem/logs/post-fs-data.log
mkdir -p /data/adb/stepsystem/logs
{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] post-fs-data trigger MODDIR=$MODDIR"
  # Some managers/devices miss or delay service.sh. Start in background after boot settles.
  (
    sleep 20
    sh "$MODDIR/service.sh"
  ) >> /data/adb/stepsystem/logs/service.log 2>&1 &
} >> "$LOG" 2>&1
