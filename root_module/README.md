# FlClash root module prototype

This module starts a standalone mihomo executable as root. It does not yet connect to the Flutter control panel. **Do not install it alongside an active FlClash VPN**: two independent cores can conflict over ports and routes.

The module stores private data in `/data/adb/flclash-root` so a module update does not erase it. Installation never reads or modifies the existing FlClash app's private files. FlClash's existing backup/restore feature remains in the app. The app-side connection and root-mode lifecycle are still under development.

Set `tun.enable: true` and `tun.auto-route: true` in the resulting configuration. Test the configuration first:

```sh
su -c '/data/adb/modules/flclash_root/bin/flclash-root test'
```

Commands: `start`, `stop`, `restart`, `enable`, `disable`, `status`, `test`. Startup on boot is disabled by default; `enable` creates a persistent autostart marker and starts the core. The daemon writes `core.log` and `core.pid` in the private data directory. The core binds any external controller specified in the user's config; keep it on loopback with a strong secret.

This is a source prototype, not a complete transparent proxy release. Android routing, DNS interception, reboot lifecycle and compatibility with the Flutter app require device testing before it can be shipped as a working solution.
