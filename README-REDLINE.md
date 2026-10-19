# Redline — Linux Graphics Edition

An open-source Linux GPU control and gaming dashboard maintained by **Slave IT Solutions** — [info@slave.gr](mailto:info@slave.gr).

Redline is a native Qt 6/QML source fork of [CoreCtrl](https://gitlab.com/corectrl/corectrl), with an integrated GPU engine derived from [LACT](https://github.com/ilya-zlobintsev/LACT). The interface targets the layout and interaction style of AMD Software: Adrenalin Edition, with Redline branding.

**Development version.** Full interface and functionality parity is not complete. There is no stable `.deb` release yet. AMD Windows binaries, recovered proprietary code and extracted assets are not distributed here. Redline is an independent project and is not an official AMD product.

## What currently works

- Native dashboard, responsive shared navigation, history, search, session notifications and feedback; Steam library discovery and favorites.
- Live CPU/GPU/RAM monitoring, time-based charts and CSV logging. Hardware sampling is adjustable from 0.25 to 5 seconds; graph history covers 10–120 seconds.
- Integrated GPU control for capabilities exposed by the Linux driver, with confirmation/revert handling, plus retained CoreCtrl CPU controls.
- GameMode, Gamescope and MangoHud detection and per-game Steam launch integration. Availability accounts for sandboxed Steam installations.
- Dark/light appearance, Greek/English core UI and a Redline tray icon.

Some pages and settings are still availability views or saved UI state. Capture/streaming, AI, VR streaming, automatic driver updates and proprietary Windows-only driver features are not implemented. FPS in the dashboard remains unavailable until a game telemetry provider is connected. Hardware support varies; unsupported controls are not unlocked by changing drivers or boot parameters.

See the [full coverage matrix and roadmap](docs/PARITY-ROADMAP.md) and [shared-shell implementation notes](docs/INTERFACE-IMPLEMENTATION.md).

## Build

The current development target is Ubuntu 26.10 amd64, Qt 6.11.2. Other distributions and older Ubuntu releases have not been validated.

The C++ build requires CMake, a C++20 compiler, Qt >= 6.8 (Core, DBus, Quick, Charts, Widgets, Network, Svg and Linguist tools), QuaZip for Qt 6, spdlog, pugixml, Botan, and GLib/Polkit development libraries. Required QML modules include QtQuick, Controls, Layouts, Templates, Window, QtQml, Models, WorkerScript, Qt Charts and Qt Labs Platform.

```sh
./build-redline.sh
./build-gpu-engine.sh
./run-preview.sh
```

The GPU engine build uses the pinned Rust toolchain declared in the vendored source and requires its native development dependencies. See [GPU engine notes](3rdparty/redline-gpu/README-REDLINE.md). `run-preview.sh` is an explicit hardware read-only development mode. `run-native.sh` uses authorized hardware control and requires the separate development helper installation. Do not run the GUI as root.

The files in `packaging/` are under development. The intended installed architecture uses narrowly scoped hardware services and a dedicated authorization group; its installation, upgrade and no-repeated-password behavior must still be validated before a binary release. Normal operating-system authorization for installing/updating software remains applicable.

## Tests

Steam launch-option editing tests:

```sh
python3 -m unittest discover -s tests -p 'test_redline_steam_options.py'
```

`tests/test_metrics_sampling.cpp` exercises the real Qt timer, sampling bounds, monotonic graph-window retention and CSV cadence without changing hardware settings. Build it with the dashboard header's generated Qt moc source and Qt6Core/Qt6Gui; run with the offscreen Qt platform.

## Licensing and attribution

Redline and its CoreCtrl-derived code are GPL-3.0-or-later; see [COPYING](COPYING), [LICENSE](LICENSE) and the preserved source notices. Vendored LACT-derived code carries its upstream MIT license and component-specific notices, which remain in `3rdparty/redline-gpu/`. Preserve all included third-party licenses when redistributing.

CoreCtrl was imported as a source snapshot, not its complete upstream Git history. The original upstream README is retained in [docs/UPSTREAM-README.md](docs/UPSTREAM-README.md). Public publication uses a fresh source snapshot; local development history and private research artifacts are excluded.
