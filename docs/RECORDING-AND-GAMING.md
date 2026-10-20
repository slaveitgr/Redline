# Recording, screenshots, graphics defaults and hotkeys

**Redline — Open-source alternative to AMD Software: Adrenalin Edition for Linux.**


## Recording

The native recording page now exposes installed software encoder profiles: VP8/WebM, VP9/WebM and H.264/MP4. H.264 requires x264, h264parse, AAC and MP4 muxer plugins; unavailable profiles are omitted. The native Debian package recommends the optional GStreamer codec packages. Minimal installations can still use the available WebM profiles.

Recording supports 30/60 fps, a 2–100 Mb/s target bitrate, and native, 720p or 1080p output. Scaling preserves aspect ratio with borders. System audio, the default microphone, or both can be selected explicitly. When mixing both, each input uses half gain to reduce clipping; the inputs are converted to 48 kHz stereo and encoded as one mixed track. Separate microphone tracks, device selection and GPU encoding remain pending. A low-rate in-memory live preview and audio activity meters now share the capture pipeline.

The screen/window is chosen through the desktop's ScreenCast portal after Start. Microphone/system-audio inputs are never opened on startup, during capability detection or in automated tests. Both the native interface and the helper reject recording in Preview mode. Stop requests EOS so the container can finalize; timeout and process errors are reported. Saved WebM/MP4 files appear in Media.

## Screenshots and Media

Home and Record & Stream provide an explicit screenshot action using the interactive Screenshot portal. The helper validates the returned local PNG, copies it with an exclusive UUID filename and private file permissions into Pictures/Redline, and never captures on startup. Media lists these PNGs alongside the recordings from Videos/Redline. Opening media is restricted to those folders and recognized file types.

The portal chooser flows still require interactive testing on each desktop; generated-source encoder tests do not establish end-to-end desktop capture support.

## Global and per-game graphics

Gaming → Graphics stores Linux launch defaults for GameMode, Gamescope, render/output size, scaling mode, filter and frame limit. A game inherits a default until a per-game override is saved. **Use global defaults** clears that game's launch overrides. Existing Steam launch options change only after the explicit Apply action, with the existing backup/restore behavior.

Tools unavailable in a game's runtime are omitted from its generated command. Gamescope overlay integration requires mangoapp. Scaling alternatives are labeled accurately: FSR here is Gamescope FSR 1.0; integer scaling and supersampling operate on game rendering. They do not enable AFMF, driver FSR frame generation, Anti-Lag or dynamic Chill behavior.

## Application hotkeys

Settings → Hotkeys configures recording toggle, metrics logging, game library and performance navigation. Bindings are normalized through Qt, reject unsuitable/unmodified keys and duplicate assignments, and can be cleared or reset. Shortcut auto-repeat is disabled so holding a recording/logging key cannot repeatedly toggle the operation.

These shortcuts work while a Redline window is active. They are not global Wayland shortcuts and do not replace MangoHud's in-game shortcut.

## Verification

- Real generated-source encode/mux tests cover installed codecs, video-only, system audio, microphone and mixed audio; stream caps, file container, output size and bitrate are checked.
- Screenshot tests validate a generated PNG copy, private permissions, invalid URIs/files and Preview rejection without contacting the portal.
- Qt tests validate key normalization and exercise the actual reusable QML shortcut, activation, repeat suppression and disabling invalid bindings.
- The native preview suite checks global/per-game inheritance and override reset, encoder discovery and new page navigation; captures are of Redline's own window.

References: [ScreenCast](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html), [Screenshot](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Screenshot.html), [Qt Shortcut](https://doc.qt.io/qt-6/qml-qtquick-shortcut.html), [GStreamer audiomixer](https://gstreamer.freedesktop.org/documentation/audiomixer/audiomixer.html), [Gamescope](https://github.com/ValveSoftware/gamescope).

## Instant Replay (development)

Opt-in portal capture retains completed two-second VP8/WebM segments in a private temporary directory, pruning old segments to the chosen 15/30/60/120 second limit (15 seconds retains 14 seconds of complete segments). Save Replay or Ctrl+Shift+S while Redline has focus snapshots the completed segments and exports a WebM without stopping capture. The newest roughly two seconds may be omitted. Stop discards the remaining buffer. ffmpeg is required and recommended by the Debian package. Microphone and system audio remain explicit choices. This uses software encoding and disk storage, not an in-memory buffer.

Generated-source tests verify segment retention, audio/video export, full decoding and cleanup. A real desktop replay session is not yet validated.
