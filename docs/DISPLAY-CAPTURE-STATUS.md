# Display and capture support

## GNOME desktop display controls

Redline queries the session's `org.gnome.Mutter.DisplayConfig` service. The Display page offers the connected display's advertised resolution/refresh modes, supported scale factors, matching fixed/variable refresh modes (Adaptive Sync), and compositor color modes (standard SDR, native SDR or HDR where exposed).

Selections are staged in the interface. Apply rereads the current configuration, validates the exact connector/mode/scale/color against fresh capabilities, asks Mutter to verify the proposed configuration, then requests a persistent change. GNOME Shell presents its standard **Keep Changes / Revert Settings** countdown dialog; Mutter reverts unconfirmed changes. GNOME Shell must be running. Read-only preview rejects Apply. No administrator access or driver configuration changes are involved.

Other active displays, rotations, primary status, color modes, underscan settings and supported layout mode are preserved. Redline does not rearrange outputs to compensate for a changed resolution/scale. If the compositor rejects the resulting geometry, use the desktop's arrangement editor. Mirrored or disabled displays must be configured in desktop settings. Hotplug changes refresh the capability list.

Adaptive Sync is enabled by selecting the compositor's advertised variable-refresh mode. Its presence is not a claim that every game, output or configuration will use VRR. Redline does not enable experimental compositor features to manufacture support.

Desktop-wide VSR, GPU integer scaling, arbitrary gamma/saturation, custom modelines and link pixel-format controls are not implemented. Per-game Gamescope render/output resolution, scaling mode and filter controls are separate from desktop display configuration. ICC profiles and monitor arrangement open the operating system's editors.

Verification includes fixture tests for capability rejection, mirrored/disabled outputs, preservation of other outputs and the exact D-Bus variant signature. On the development laptop, real compositor verification (method 0, no change) accepted current configuration and a proposed fractional-scale/VRR/native-SDR configuration. Actual changes and countdown recovery still require interactive validation; automated tests do not alter the user's desktop.

References: [Mutter display interface](https://github.com/GNOME/mutter/blob/main/data/dbus-interfaces/org.gnome.Mutter.DisplayConfig.xml), [GNOME Shell confirmation dialog](https://github.com/GNOME/gnome-shell/blob/main/js/ui/windowManager.js), [Gamescope](https://github.com/ValveSoftware/gamescope).

## Experimental local recording

Record, Media and recording Settings now use a native portal/PipeWire/GStreamer backend. Recording starts only after a user action and the desktop's screen/window chooser. Output is VP8/WebM at 30 or 60 fps, with optional experimental default-output monitor audio. Stop finalizes the file; Media lists actual saved recordings. There is no embedded live preview.

The real encoder/muxer is tested with generated video and audio sources, without recording the desktop. End-to-end desktop portal capture has not yet been interactively validated. Required plugins and portal support are checked; read-only preview cannot record.

Live streaming, scene editing, instant replay/GIF, microphone tracks and alternative codecs remain pending. Settings for those features are not active recording controls.

Reference: [ScreenCast portal](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html).
