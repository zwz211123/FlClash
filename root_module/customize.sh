#!/system/bin/sh

ui_print 'FlClash root core installer'

if [ "$(getprop ro.product.cpu.abi)" != arm64-v8a ]; then
  abort 'This build only supports arm64-v8a.'
fi
if [ ! -f "$MODPATH/bin/flclash-core" ]; then
  abort 'Missing bin/flclash-core. Use the built module ZIP, not a source archive.'
fi

DATA_DIR=/data/adb/flclash-root
mkdir -p "$DATA_DIR" || abort 'Cannot create private module data directory.'
chmod 700 "$DATA_DIR" "$MODPATH/bin"
chmod 755 "$MODPATH/bin/flclash-core" "$MODPATH/bin/flclash-root" "$MODPATH/service.sh"

ui_print 'Installed. FlClash app backup and restore remain unchanged.'
ui_print 'The core remains disabled until configured and started.'
