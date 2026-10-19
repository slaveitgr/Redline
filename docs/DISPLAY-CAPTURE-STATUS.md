# Display and capture status

The Windows package's settings layout is a reference, not a Linux capability provider. Display currently detects connected screens and reports their names, logical dimensions, refresh rates and Qt scale/surface depth, with links to Ubuntu's display/color settings.

- Adaptive Sync/VRR: no validated per-output compositor control is connected in Redline. Unavailable does not mean the Linux system lacks VRR.
- Virtual Super Resolution: no desktop-wide VSR control is implemented. Per-game supersampling is a separate possible Gamescope integration.
- GPU scaling/integer scaling: no global driver control is exposed. Gamescope can implement per-game scaling, but those additional recipe controls are not yet wired in Redline.
- Color depth: the displayed Qt surface depth is not a claim about monitor link bit depth. Pixel format, custom color and custom modes remain unconnected.

Record & Stream currently has navigation and saved setup preferences only. Actual screen/audio capture, encoding, streaming, scenes, replay/GIF and media management are not connected. The page banner explicitly distinguishes setup preferences from active recording. A first functional Linux implementation needs portal-based screen selection under Wayland, PipeWire frame/audio handling, a validated encoder/muxer and recording lifecycle/error handling; streaming and replay follow after local recording works. No current recording or broadcast capability is claimed.

Gamescope reference: https://github.com/ValveSoftware/gamescope .
