# FlClash root module prototype

This module starts a standalone mihomo executable as root. It does not yet connect to the Flutter control panel. **Do not install it alongside an active FlClash VPN**: two independent cores can conflict over ports and routes.

The module stores its process log, PID and the path to the active app configuration in `/data/adb/flclash-root`. Installation never reads or modifies the existing FlClash app's private files. FlClash's existing backup/restore feature remains in the app. The app-side connection and root-mode lifecycle are still under development.

The module reads FlClash's generated `config.yaml` directly from the app data directory; it does not copy profiles or scripts. Set `tun.enable: true` and `tun.auto-route: true` in the generated configuration. Until the control panel is connected, configure the source path and test it first:

```sh
su -c '/data/adb/modules/flclash_root/bin/flclash-root configure /data/user/0/com.follow.clash/files/config.yaml'
su -c '/data/adb/modules/flclash_root/bin/flclash-root test'
```

Commands: `configure`, `start`, `stop`, `restart`, `enable`, `disable`, `status`, `test`. Startup on boot is disabled by default; `enable` creates a persistent autostart marker and starts the core. `configure` stores only the app config path, not a copy of the file. The daemon writes `core.log` and `core.pid` in the private data directory. The core binds any external controller specified in the user's config; keep it on loopback with a strong secret.

This is a source prototype, not a complete transparent proxy release. Android routing, DNS interception, reboot lifecycle and compatibility with the Flutter app require device testing before it can be shipped as a working solution.
