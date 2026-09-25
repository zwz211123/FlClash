#!/system/bin/sh
MODDIR="${0%/*}"
[ -f /data/adb/flclash-root/autostart ] || exit 0
"$MODDIR/bin/flclash-root" start
