# Easy VR setup

**Redline — Open-source alternative to AMD Software: Adrenalin Edition for Linux.**


The ReLive VR page now provides Install/Open buttons for ALVR and WiVRn, a source/scope confirmation, progress/errors and refreshed detection after success. No installation runs on app startup or merely selecting a backend. Installation is blocked in the read-only UI preview.

ALVR downloads only the official alvr-org/ALVR Linux launcher release asset using GitHub's latest-release metadata. The asset URL, size and SHA-256 digest are checked. Extraction rejects traversal, links/special files, excessive entry counts and unbounded output. Files are staged in a user-owned temporary folder and atomically published only after validation. The selected release version/hash is recorded; no downloaded executable is run by the installer. The launcher is opened only by a separate user action and handles subsequent ALVR/SteamVR/headset setup. This first automatic path supports x86_64 and needs Python with tarfile data filters (Ubuntu 24.04+ supports this).

WiVRn uses the installed Flatpak executable and an already-configured official flathub remote. A user remote is preferred; otherwise an existing system remote is used and may invoke normal administrator authorization. Only io.github.wivrn.wivrn is installed. No remote is silently added and no firewall, driver, security or repository configuration is altered by Redline. Missing Flatpak/Flathub leads to a setup-guide button. Flatpak runtime dependencies may be substantial; system Flatpak installation requires the normal user's authorization.

Tests use synthetic archives and a fake Flatpak process, never a real backend installation: valid atomic install, corrupted hash rejection, path/link rejection, preview guard, user/system scope, fixed package/source and missing/untrusted remote. Native preview captures show the action and confirmation controls. No headset stream or real installation has been validated in this pass.

Sources: https://github.com/alvr-org/ALVR and https://flathub.org/apps/io.github.wivrn.wivrn .
