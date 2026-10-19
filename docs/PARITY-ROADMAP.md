# Redline interface and functionality parity

The target is a complete Adrenalin-style Linux application, including navigation, page layouts, dialogs and working controls. A matching interface does not imply that proprietary Windows driver functionality is available on Linux. Recovered AMD source and binary assets are not included in this repository.

## Coverage and acceptance criteria

| Area | Current Redline implementation | Remaining work |
| --- | --- | --- |
| Main shell | Shared navigation components, responsive search, vector R branding, back/forward history, session notifications with unread state, feedback and settings actions, navigation drawer | Continue page-specific visual comparisons; implement compact/in-game sidebar window mode and complete keyboard interaction coverage |
| Home | Three-column dashboard, discovered games, hardware information | Functional recent activity and media; consistent layout at each supported window size |
| AI / Chat / Apps | Session chat and local model discovery via Ollama, optional hardware snapshot | Document retrieval, image generation, real hardware inference validation |
| Gaming / Games | Installed Steam games, search, sort, favorites, per-game settings, launch recipes | Playtime and game telemetry; persistence and refresh on library changes |
| Gaming / Graphics | Layout, global/per-game scope, explicit unavailable proprietary settings | Linux implementations for each supported graphics setting; driver-specific detection |
| Gaming / Advisors | Availability page | Recommendations based on measured sessions |
| Record & Stream / Record | Navigation and unavailable state | Portal-based capture, preview, audio/device controls, encoder selection and real recording |
| Live Stream / Scene Editor / Media / Capture Settings | Page structure and saved settings | Real streaming, scenes, media management and coordinated recording state |
| Performance / Metrics | Live GPU/CPU/RAM sensors, charts, visibility, CSV logs | Game FPS/frame-time provider, per-metric graph/gauge/overlay controls, metric profiles and multi-GPU selection |
| Performance / Tracking | Hardware sample cadence and actual CSV output | Independent frame-metric interval and full tracking controls |
| Performance / Overlay | MangoHud launch integration, position, font, opacity, 12 metric flags, layout, profiles, hotkey and FPS limit settings | Live control where supported and column sizing; individual metric flags, profiles, hotkey and shared Preferences switch are implemented |
| Performance / Tuning | Integrated LACT-derived GPU engine, CoreCtrl CPU controls, supported controls and confirmation/revert flow | Rebuild remaining inherited forms to match the target layout; per-device/per-game state, preset import/export and supported advanced fan/clock controls |
| Performance / Settings | Graph duration connected to time-based history | Validated custom log directory and hide-overlay-during-logging behavior |
| Smart Technology | Availability states | Linux equivalents where possible; capability detection rather than enabled-looking placeholders |
| Settings / System | Actual system/device details, About and upstream credits | Scoped snapshot import/export and reset with validation/backup implemented; issue-report file export and live update checking remain |
| Settings / Display | Connected-display discovery and desktop settings integration | Compositor-aware color, scaling, VRR and supported per-display settings |
| Settings / Audio & Video | Page structure | Linux audio processing and video profiles |
| Settings / Hotkeys | Availability states | Bindings tied to implemented actions, conflict handling and Wayland support |
| Settings / ReLive VR | SteamVR status, native ALVR/WiVRn and WiVRn Flatpak detection, explicit dashboard launch, ALVR launcher and WiVRn installation actions | Direct headset/session/settings integration and headset validation; the AMD Windows runtime is not portable as-is |
| Settings / Preferences | Dark/light theme, Greek/English core UI, Redline tray branding and saved preferences | Complete translations, audit every toggle for real effects and remove inactive settings from enabled control states |
| Distribution | Independent application IDs, source builds, scoped service/package files in development | Finish Debian package build, install/upgrade/removal verification, authorization lifecycle and release automation |

## Findings guiding the implementation

Static inspection of the supplied Windows package confirms separate navigation, metrics monitoring, metrics overlay, tuning and notifications components. The observed performance navigation consists of Metrics, Tuning and Settings; Tracking and Overlay belong inside Metrics. Tuning visibility is capability-dependent. Routes include global and per-GPU tuning, per-game GPU tuning, recording, streaming, scenes, media, system, display, audio/video, hotkeys and VR settings.

These findings guide behavior and coverage. Source filenames, symbol names and route strings alone do not prove that a feature is enabled, licensed, complete or functional on a particular device. The public implementation uses original Redline code and the licensed CoreCtrl/LACT sources.

## Implementation order

1. Finish the source publication and clearly mark the current version as development.
2. Complete the shared shell, routing and state contract for every page, with visual reference comparisons.
3. Finish Performance end-to-end: real telemetry, tracking, overlay, tuning, profiles, Apply/Keep/Revert and device capabilities.
4. Implement capture/streaming/media and preferences/hotkeys with real Linux services.
5. Address remaining graphics/display, VR and AI integrations individually, with explicit support detection.
6. Validate packaging, first-run setup, upgrades and removal before publishing installable release artifacts.

No claim of full parity or a stable public binary release is made at this stage.
