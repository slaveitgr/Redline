# Redline fork changes — 2026-10-19

Upstream input: user-supplied CoreCtrl 1.6.0-dev source ZIP.

- Renamed project/application, output binaries, local configuration and D-Bus/Polkit namespace.
- New native Home and Performance QML; horizontal app navigation; Redline colors and artwork.
- In-process dashboard/Steam presentation model.
- Original profile manager, hardware providers, sensor graphs and controls remain in-process.
- Explicit read-only transport adapters for UI development, consuming and discarding hardware command queues and disabling process monitoring.
- Preview-only Apply/manual-activation guards and a screenshot/model smoke-test path.
- Isolated optional local dependency sysroot support; staged local builds and separate reviewed helper installer.
- Restored two SVG symbolic links from the supplied archive.
- Existing GPL copyright/license notices retained. New fork code is GPL-3.0-or-later.

## Toolbar refinement
Restored the supplied dashboard v2 navigation spacing, inset active underline, back/forward history, game search, and SVG toolbar icons. Removed the redundant Home subheader. Native read-only smoke test passed after rebuilding.

## 0.5.0 unified interface
Rebuilt Home around the supplied HTML, shared the new About across menu and Settings, restored the supplied feature banner, aligned Performance panels with the reference, styled buttons and hardware tabs, and removed Native from product display names. The in-process hardware core is retained; preview mode and hardware write guards are unchanged.

## 0.6.0 native v6 navigation
Integrated a native route model, game library/favorites/details, persistent UI settings, HTML-derived settings catalog and feature pages, contextual tabs, expanded search and Tracking/Overlay preference views. Preserved Redline toolbar artwork, branding and compiled hardware core. Imported controls are capability-gated; unavailable services are explicitly identified. Added native route/preference regression smoke checks and filtered Steam runtime manifests.

## 0.7.0 grouped Settings pages
Replaced System/Display/Preferences generic/tabbed presentation with dedicated two-column settings, reusable rows and collapsible groups. Retained upstream SYSTEM_INFO for diagnostics and details. Added read-only Qt/sysfs system/display metadata and allowlisted Ubuntu Settings shortcuts. Bound supported preferences to actual app settings and implemented save-notification animations. Extended native smoke coverage; original toolbar assets and hardware write guards are unchanged.

## 0.8.0 appearance, language and VR availability
Added reactive Light/Dark palette, persistent Greek/English UI selection, bundled R tray icon, and ReLive VR availability workspace. Retained raw route/setting identifiers and hardware product names. Added isolated appearance/language/VR smoke and captures. No VR streaming backend is installed or claimed.

## Gaming library refinement
Reworked responsive cards, filter/sort/favorites and artwork fallback. Replaced generic game settings list with Graphics/Display columns; removed misleading editable per-game mode selector. Preserved hardware capability guards and original toolbar. Added native captures and filter/favorite smoke checks.

## Performance metrics and tuning refinement
Rebuilt Metrics into live sensor columns and Tracking/Overlay sidebar. Added persisted metric visibility, local hardware CSV logging, optional k10temp sampling and appearance-aware chart repaint. Replaced hardware tabs/splitters with vertically stacked tuning sections and backend mode buttons. Preserved QML plug identities, profile workflows and hardware write guards. Added native captures, visibility regression and CSV verification. Inspected supplied video frames and recorded LACT source/API assessment.

## Authorized hardware-control mode
Installed the independent Redline helpers with administrator authentication and switched the user desktop shortcut to run-native.sh. Verified authenticated helper started state over D-Bus. Added a launch-only skip-startup-apply diagnostic, longer desktop authentication timeout, helper restart failure guard and explicit initialization diagnostics. Added real VRAM, memory clock and fan telemetry where exported. No permissive authorization rules, driver/repository/boot changes or LACT daemon installation.

## 0.9.0 LACT source integration
Vendored the actual LACT Rust GPU engine/schema with MIT notices, added a private stdio/embedded-socket Redline executable and separate root config namespace. Added an asynchronous native Qt adapter and GPU tuning workspace, telemetry, capability-gated performance/power/fan controls and real confirmation/revert transactions. Removed CoreCtrl GPU control providers in this mode; CPU remains CoreCtrl. Installed a root-owned engine through normal administrator authentication. Full LACT GUI parity is not claimed; custom clock/curve/profile editors remain to map.

## Gaming tools and real overlay connection
Added runtime-aware GameMode/Gamescope/MangoHud detection, GameMode status, per-game Steam connection/copy/restore and persisted shared MangoHud configuration. Replaced the unavailable Overlay controls with working preferences for connected launches. Added guarded VDF editing and five regression tests; preserved actual Steam config while it is running. Verified host/Snap overlay loading and documented Gamescope's sandbox limitation.
