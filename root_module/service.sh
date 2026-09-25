#!/system/bin/sh
MODDIR="${0%/*}"
[ -f /data/adb/flclash-root/autostart ] || exit 0
# Credential-encrypted app files may appear only after the first unlock.
# The retry window also covers slow storage mounts without blocking boot.
attempt=0
while [ "$attempt" -lt 120 ]; do
  [ -f /data/adb/flclash-root/autostart ] || exit 0
  if "$MODDIR/bin/flclash-root" start; then
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 5
done
exit 1
