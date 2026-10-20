# Driver compatibility and VR integration

> **Redline** is an independent, open-source alternative to **AMD Software: Adrenalin Edition** for Linux. This page documents one part of the native Linux implementation; features and parity depend on hardware, drivers and desktop support. [Project overview](../README.md).

## Windows package reference findings

Focused static analysis of the privately recovered Settings/System, Dashboard/DriverUpdate, Settings/ReliveVR, Settings/VrDevicePairPopup and Settings/VrStreamingSetting components confirms a separate driver/update surface and VR device, pairing, SteamVR integration, headset profile, controller, bitrate and UDP/TCP settings. These are feature-gated Windows model bindings; their presence does not establish Linux support. No recovered AMD QML, binary assets or native implementation is distributed.

The supplied Radeon-ReLive-VR-master.zip contains a README, changelog, issue templates and ReLiveVR-Oculus-1.0.26.apk. It contains no PC streaming-server source. The upstream README requires Windows/Adrenalin for the PC host. This archive cannot supply a native Linux server by itself.

## Driver feature implemented

Settings > System displays actual OS/kernel/architecture, DRM GPU vendor/device/driver and installed Mesa/vendor-package versions from a bounded read-only dpkg-query. There is no installer or repository modification. The reference catalog is Radeon Software for Linux 26.16, released 2026-10-05 and verified 2026-10-20. Its Ubuntu OS targets are 24.04.5 HWE and 26.04.1. Ubuntu 26.10 is explicitly unlisted. A matching major/minor family never claims full compatibility: the point release, kernel and exact GPU still require verification. Non-Ubuntu distributions are unvalidated in this first catalog, not declared globally unsupported.

The vendor package is not mislabeled as wholly proprietary. Licensing is component-specific; this feature does not independently establish proprietary-component availability or GPU compatibility. The catalog is explicitly versioned and offline. AMD downloads/release-note buttons open official sites on request; no claim of a live update check is made.

## VR feature implemented

The ReLive VR workspace retains the familiar devices, integration, settings and streaming structure with original Redline QML. Discovery checks native ALVR dashboard/launcher and WiVRn dashboard/server; WiVRn Flatpak is recognized from deployed metadata for io.github.wivrn.wivrn. Available dashboards can be explicitly launched. Discovery never launches them automatically. Pairing, bitrate, resolution, encoder and audio remain managed by those dashboards; Redline does not report invented connected headsets or toggle unsupported Windows driver registration.

ALVR follows the SteamVR route. WiVRn uses OpenXR and may require xrizer/OpenComposite for OpenVR games, so SteamVR is not imposed as a universal WiVRn prerequisite. No backend was installed, no firewall or service configuration changed, and headset streaming has not been tested. Each user selects their own headset in the chosen backend's setup wizard. The backend choice is saved in Redline. Direct connection-state/settings APIs need version-specific validation and representative headset testing before exposing controls; the application is not tailored to the developer's personal headset.

## Verification

The standalone test_system_integration.cpp checks OS/architecture gating, no full compatibility inferred from an OS family, native executable discovery, no automatic launch and an explicitly requested allowlisted launch using a local fixture. Native preview tests cover System and ReLive VR in dark/light and Greek/English presentation. No driver installation or real headset streaming was exercised.

Sources:
- https://www.amd.com/en/resources/support-articles/release-notes/RN-AMDGPU-UNIFIED-LINUX-26-16.html
- https://github.com/GPUOpen-LibrariesAndSDKs/Radeon-ReLive-VR
- https://github.com/alvr-org/ALVR
- https://github.com/WiVRn/WiVRn
