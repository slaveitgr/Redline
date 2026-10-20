# Interface implementation: first shared-shell pass

> **Redline** is an independent, open-source alternative to **AMD Software: Adrenalin Edition** for Linux. This page documents one part of the native Linux implementation; features and parity depend on hardware, drivers and desktop support. [Project overview](../README.md).

This pass implements the shared shell using original Redline QML and SVG code. It is based on observed interface behavior and measured geometry, with Redline branding. Recovered AMD application sources and binary resources remain private research inputs.

## Implemented behavior

- A 56-pixel main navigation bar, 42-pixel contextual navigation row and shared 40-pixel buttons.
- Six primary sections: Home, AI, Gaming, Record & Stream, Performance and Smart Technology. Settings opens from the gear, and Notifications opens from the bell. Each action has a matching selected state.
- The Redline home tile uses the same original R artwork as the application icon. Back and forward use arrows with shafts. Notification and feedback icons have solid silhouettes.
- The star opens Redline Feedback, with an explicit button that opens this repository's Issues page. It does not send an issue automatically. Favorite games remain available in Gaming and the navigation drawer.
- The rightmost action opens a navigation drawer. This is a functioning navigation panel; the Windows application's compact/in-game sidebar window mode is still a separate future feature.
- Capture and Performance each have a contextual tab named Settings. Old internal labels remain accepted as navigation aliases.
- At narrower widths, the primary tabs use tighter spacing and search becomes an icon. A search field inside the dialog remains available. Ctrl+F, Alt+Left and Alt+Right work in the shell.
- Notifications represent actual session events, such as the explicit development-preview state and GPU backend errors. Duplicate event keys are suppressed, unread counts update, and individual/all-read/clear-read operations affect the same model displayed by the bell and page. No sample success notifications are inserted.
- Greek translations cover the added controls. Theme changes use the existing live appearance model. The original Redline banner typography is centered so cropping at different card sizes keeps it visible.

## Verification

The native application preview exercises route history, settings, appearance/language, gaming discovery/favorites, performance visibility and the notification lifecycle. The shell test adds and removes its own temporary event, verifies unread state, visits Notifications, opens the drawer and restores its prior route.

Development previews now use a separate single-instance identifier, allowing the actual read-only UI test to run alongside an existing normal Redline session without activating that older process. Preview captures use separate configuration/cache/data directories. Preview MangoHud settings also have their own path, so test preferences do not overwrite the normal game-overlay configuration.

An intentional invalid-UI check reproduced the initialization failure and verified a clean error exit after cleanup was added: worker threads are joined and pending GameMode status processes are stopped. The invalid fixture was then removed and the valid UI rebuilt.

The test renders the actual compiled application. It does not apply hardware settings. This is the first shared-shell pass, not a claim of complete page-by-page visual or functional parity.

## Evidence guiding subsequent implementation

Static analysis of the supplied Windows package recovered 548 QML files plus one JavaScript file from the executable's two embedded resource trees. All 549 recovered payload hashes were checked against an independent Qt resource reader. The package's 217 executable images were indexed for imports/exports.

Qt metadata for 312 classes exposed 1,753 properties and 2,724 methods/signals. Class/property names, readable/writable/constant flags, method names/kinds/access and enum counts were independently checked with Linux Qt using data-only buffers and harmless local type interfaces. Target getters, functions and Windows code were not called. All 49 decoded Qt enum tables also matched separate PDB type records.

These facts provide interface contracts, support gates and state transitions to implement against Linux backends. Native procedure indexing and selected call traces are partial static analysis; indirect calls, driver behavior and complete runtime equivalence still require further investigation and testing.

## Metrics controls and staged tuning follow-up

Metrics now use sensor gauges, individually persisted graph visibility, and a real 10/30/60/120-second graph window. Frame time and 99% FPS have separate unavailable keys until a real frame telemetry source is connected. Tuning retains staged edits on backend errors and locks edits, adapter changes and repeated Apply during submission and rollback confirmation. The preview smoke suite passes; hardware writes were not exercised in this UI pass.
