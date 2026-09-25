#!/system/bin/sh

ui_print 'FlClash root core installer'
ui_print 'arm64 only; a standalone mihomo binary must be packaged.'

if [ "$(getprop ro.product.cpu.abi)" != arm64-v8a ]; then
  abort 'This build only supports arm64-v8a.'
fi
if [ ! -f "$MODPATH/bin/mihomo" ]; then
  abort 'Missing bin/mihomo. Use the built module ZIP, not a source archive.'
fi

DATA_DIR=/data/adb/flclash-root
mkdir -p "$DATA_DIR" || abort 'Cannot create private module data directory.'
chmod 700 "$DATA_DIR"

choose_key() {
  while true; do
    key="$(getevent -qlc 1 2>/dev/null)"
    case "$key" in
      *KEY_VOLUMEUP*|*KEY_VOLUME_UP*) return 0 ;;
      *KEY_VOLUMEDOWN*|*KEY_VOLUME_DOWN*) return 1 ;;
    esac
  done
}

ui_print 'Migrate existing FlClash files? Volume Up = yes; Volume Down = no.'
if choose_key; then
  SOURCE_DIR=
  for candidate in /data/user/0/com.follow.clash/files /data/data/com.follow.clash/files /data/user/0/com.follow.clash.dev/files /data/data/com.follow.clash.dev/files; do
    if [ -f "$candidate/config.yaml" ]; then
      SOURCE_DIR="$candidate"
      break
    fi
  done
  if [ -z "$SOURCE_DIR" ]; then
    ui_print 'No existing config.yaml found; leaving module data empty.'
  else
    ui_print "Source: $SOURCE_DIR"
    ui_print 'Volume Up = copy files; Volume Down = link to app files.'
    if choose_key; then
      for name in config.yaml profiles scripts Country.mmdb GeoIP.dat GeoSite.dat ASN.mmdb; do
        if [ -e "$SOURCE_DIR/$name" ] && [ ! -e "$DATA_DIR/$name" ]; then
          cp -R "$SOURCE_DIR/$name" "$DATA_DIR/$name" || abort "Copy failed: $name"
        fi
      done
      ui_print 'Copied config, profiles, scripts and existing geo resources.'
    else
      for name in config.yaml profiles scripts Country.mmdb GeoIP.dat GeoSite.dat ASN.mmdb; do
        if [ -e "$SOURCE_DIR/$name" ] && [ ! -e "$DATA_DIR/$name" ]; then
          ln -s "$SOURCE_DIR/$name" "$DATA_DIR/$name" || abort "Link failed: $name"
        fi
      done
      ui_print 'Linked existing files. Uninstalling the app will break the links.'
    fi
  fi
else
  ui_print 'No migration selected.'
fi

chmod 700 "$MODPATH/bin" "$DATA_DIR"
chmod 755 "$MODPATH/bin/mihomo" "$MODPATH/bin/flclash-root" "$MODPATH/service.sh"
ui_print 'Configure tun.enable and tun.auto-route in config.yaml before starting.'
