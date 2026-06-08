SKIPUNZIP=0
ui_print "*******************************"
ui_print " 步数管理"
ui_print "*******************************"
ui_print "安装后会尝试启动本地服务: http://127.0.0.1:8058/"
ui_print "若打不开，请在模块列表点击执行按钮生成诊断。"
ui_print "诊断日志: /sdcard/步数管理-action.log"
ui_print "服务日志: /sdcard/步数管理-service.log"


# Fix permissions after module extraction. Some managers unzip embedded runtime as 0644.
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/scheduler-daemon.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm_recursive "$MODPATH/php/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/php/libexec" 0 0 0755 0755
set_perm_recursive "$MODPATH/php/lib" 0 0 0755 0644

# Do not start from /data/adb/modules_update during installation: that path is temporary.
# service.sh/post-fs-data.sh will start the service after reboot from /data/adb/modules/stepsystem.
ui_print "安装完成后请重启；重启后会自动启动: http://127.0.0.1:8058/"
