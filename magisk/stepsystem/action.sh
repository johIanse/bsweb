#!/system/bin/sh
MODDIR=${0%/*}
case "$MODDIR" in
  /*) ;;
  *) MODDIR="$(cd "$MODDIR" 2>/dev/null && pwd)" ;;
esac
[ -n "$MODDIR" ] || MODDIR=/data/adb/modules/stepsystem
LOG=/sdcard/步数管理-action.log
{
  echo "===== 步数管理 手动诊断 $(date '+%Y-%m-%d %H:%M:%S') ====="
  echo "MODDIR=$MODDIR"
  echo "module.prop:"
  cat "$MODDIR/module.prop" 2>&1
  echo
  echo "run service.sh:"
  sh "$MODDIR/service.sh" 2>&1
  echo
  echo "process:"
  ps -A 2>/dev/null | grep -E 'php|stepsystem|scheduler-daemon' || true
  echo
  echo "port 8058:"
  (ss -tunlp 2>/dev/null || netstat -tunlp 2>/dev/null) | grep 8058 || true
  echo
  echo "service log:"
  tail -160 /data/adb/stepsystem/logs/service.log 2>&1
  echo
  echo "php server log:"
  tail -160 /data/adb/stepsystem/logs/php-server.log 2>&1
  echo
  echo "scheduler log:"
  tail -160 /data/adb/stepsystem/logs/scheduler.log 2>&1
  echo
  echo "post-fs-data log:"
  tail -80 /data/adb/stepsystem/logs/post-fs-data.log 2>&1
} | tee "$LOG"
echo "诊断日志已保存: $LOG"
echo "服务日志也会复制到: /sdcard/步数管理-service.log"
echo "浏览器打开: http://127.0.0.1:8058/"
echo "默认管理员: admin / admin123"
