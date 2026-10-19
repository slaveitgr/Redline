# LACT source assessment for Redline

Inspected the supplied LACT-master.zip without running its code or installing a daemon.

## Evidence in the supplied archive
- README.md: GPU monitoring, historical graphs/CSV, clocks, voltage offset, power caps, fan curves, AMD firmware thermal controls and automatic profiles; GPU support varies.
- Cargo.toml: separate lact-daemon, lact-schema, lact-client, lact-gui and CLI crates; Rust workspace, GTK UI. Redline remains Qt/C++/QML.
- docs/API.md and lact-schema/src/request.rs: newline-delimited JSON protocol, local Unix socket /run/lactd.sock, device_info/device_stats/clocks/config read endpoints, set_gpu_config plus confirm_pending_config. The documentation describes automatic rollback of unconfirmed changes, default five seconds.
- LICENSE: MIT, Ilya Zlobintsev; preserve copyright/license if incorporating source.
- lact-daemon/src/server/gpu_controller: AMD, Intel and Nvidia implementations; backend availability does not guarantee each control on Mike's Ryzen APU.

## Proposed implementation path
1. Keep the current Metrics/Tuning UI and existing CoreCtrl integration stable.
2. Build a capability comparison against the real GPU, beginning with read-only telemetry. Never enable unavailable sliders by assuming generic AMD support.
3. Decide on one authority per GPU control before adding writes; avoid competing CoreCtrl and LACT controllers.
4. For the requested integrated fork, consider a Redline-owned Rust backend/library derived from LACT with preserved MIT notices and an explicitly versioned interface. This is a separate implementation project, not already integrated.
5. Bring over confirmation/rollback semantics before enabling clock/voltage/power/fan writes. Do not expose only a cosmetic timeout.
6. Validate with dedicated hardware tests; no driver, kernel parameter, repository, service or security configuration changes are part of this assessment.

The ZIP is actual source, unlike the ReLive headset APK archive. It does not supply AMD's proprietary Windows gaming features or game FPS capture automatically. No LACT daemon has been started or installed by this task.

Archive revision: 705cc8e66706b05568cd49fe2f07bfe1476b7456
SHA256: 0bcab4e79031ea71124029452a019c560cf09add4f3f440452ca7138f822872a

## Integration update
Superseded assessment: the source is now vendored and built as Redline's private GPU engine. See README-REDLINE.md section 0.9.0 for implemented native controls, exclusive GPU ownership, validation and remaining UI work.
