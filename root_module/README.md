# FlClash root core (arm64)

This module runs FlClash's Go core as an independent root process. The Android app generates `config.yaml` and keeps its existing profiles, scripts, and backup/restore UI. Its Core RPC connects to the module over an authenticated loopback socket. The module uses Linux TUN auto-route instead of Android `VpnService`.

Build from a checkout with the `core/Clash.Meta` submodule populated and Go installed:

```sh
bash tool/build_root_module.sh
```

Install the generated ZIP and the matching Android app build. On its first start the app creates a private control token, registers its config path, and starts the root core. Enable **TUN** in the app's Network settings to capture system traffic. The start button controls listeners and the module's boot marker; stopping the proxy removes its routes but keeps the control process available. Closing the app leaves a running proxy intact. On reboot the module restores its last generated config and selected groups when the boot marker is present.

Module state and logs are in `/data/adb/flclash-root`; the app retains its own configuration files. The control server listens only on `127.0.0.1:17901` and requires a token stored in the app's private files directory. Available root commands are `configure`, `start`, `stop`, `restart`, `enable`, `disable`, `enabled`, `status`, and `test`.

The Android build hook skips the embedded Go library and the Android native project no longer compiles its JNI bridge. The VPN service, VPN notification actions, Quick Settings tile, and launcher toggle shortcut are disabled in this branch. The module and APK must both compile successfully before installation. TUN route installation, DNS interception, and boot behavior require verification on a rooted arm64 device.
