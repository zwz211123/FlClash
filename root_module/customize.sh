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
  FALLBACK_DIR=
  for user_root in /data/user/[0-9]* /data/data; do
    [ -d "$user_root" ] || continue
    for package in com.follow.clash com.follow.clash.dev; do
      for directory in files app_flutter; do
        candidate="$user_root/$package/$directory"
        [ -d "$candidate" ] || continue
        if [ -f "$candidate/config.yaml" ]; then
          SOURCE_DIR="$candidate"
          break
        fi
        if [ -z "$FALLBACK_DIR" ] && { [ -d "$candidate/profiles" ] || [ -d "$candidate/scripts" ]; }; then
          FALLBACK_DIR="$candidate"
        fi
      done
      [ -n "$SOURCE_DIR" ] && break
    done
    [ -n "$SOURCE_DIR" ] && break
  done
  [ -n "$SOURCE_DIR" ] || SOURCE_DIR="$FALLBACK_DIR"
  if [ -z "$SOURCE_DIR" ]; then
    ui_print 'No FlClash profiles or scripts found; migration skipped.'
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
    if [ ! -f "$DATA_DIR/config.yaml" ]; then
      ui_print 'No generated config.yaml found. Profiles/scripts were migrated, but the module cannot start yet.'
      ui_print 'Generate or provide config.yaml before using flclash-root start.'
    fi
  fi
else
  ui_print 'No migration selected.'
fi

chmod 700 "$MODPATH/bin" "$DATA_DIR"
chmod 755 "$MODPATH/bin/mihomo" "$MODPATH/bin/flclash-root" "$MODPATH/service.sh"
ui_print 'Configure tun.enable and tun.auto-route in config.yaml before starting.'
