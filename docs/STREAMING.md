# Custom live streaming

## Original application reference

Static inspection of the user-provided Windows package identified separate Streaming, StreamingControlPanel, StreamingSidebar and DvrSettingsStreaming components. Observed controls include Controls/Chat, Stream Preview, offline/online status, custom URL/key, account/server selection, title/description/audience, profiles (Low/Medium/High/Ultra/Custom/Adaptive), resolution, FPS, video/audio bitrates, enhanced filtering and Archive Stream. These observations inform the Redline layout and feature list; account-specific availability has not been dynamically validated.

## Implemented in Redline

Record & Stream → Live Stream uses a left Controls/Chat panel and right status/preview area. Custom RTMP/RTMPS sends portal-selected screen/window video through software H.264 and AAC to an FLV/RTMP sink. There are Low/Medium/High/Ultra/Custom presets, 720p/1080p, 30/60 FPS, video/audio bitrates, and optional default system audio/microphone. Capture, replay and streaming are mutually exclusive. The system chooser opens only after explicit Go Live. Stop also cancels pending source selection. Preview mode cannot stream.

The stream key is password-masked, not persisted, cleared from the field when starting, and passed to the capture helper over stdin rather than process arguments. Server/key are never written to preferences. Streaming errors use generic messages and raw GStreamer diagnostics are suppressed for streaming. The application disables GStreamer debug-file and graph dumping in its streaming child. No account token or external API is required for Custom Stream.

The status indicates local pipeline activity, not verified public platform delivery. Confirm the audience/title and actual delivery in the service dashboard. No stream is started automatically. Server URL needs an application path, e.g. `rtmps://server.example/live`; the key is a separate field. Query-bearing server URLs and embedded login credentials are rejected.

## Remaining scope

OAuth account sign-in, chat/viewer APIs, scene compositing, hardware encoder selection, adaptive bitrate and enhanced filtering are not implemented. Stream keys are session-only; keyring persistence is not implemented. RTMPS uses the sink's default TLS certificate validation. No external streaming service has been tested yet.

## Validation

Generated content only: a loopback FFmpeg RTMP receiver accepted 720p H.264/AAC and its saved stream decoded completely. Tests cover destination validation, Preview refusal before credential/portal access, credential redaction in streaming errors, and a bounded failure for an unreachable loopback server. The UI suite checks routing, presets and empty credential fields. Archive Stream uses the same encoded H.264/AAC buffers for the RTMP and MP4 branches. A generated live-source test invokes Stop/EOS after four seconds, verifies one video/audio encoder, and fully decodes both the received stream and finalized archive. Actual desktop capture was validated separately for ordinary recording; desktop-to-external-service streaming is pending.

The transport follows the documented [GStreamer rtmp2sink](https://gstreamer.freedesktop.org/documentation/rtmp2/rtmp2sink.html) and [flvmux](https://gstreamer.freedesktop.org/documentation/flv/flvmux.html) interfaces.

## Archive Stream

An opt-in Archive Stream switch saves a local MP4 in Videos/Redline while sending RTMP. The completed file appears in Media after Stop Streaming. The unfinished archive is hidden from Media during capture. Encoding is shared; only muxing and disk writing are additional work. A normal Stop/EOS is required to finalize MP4. A connection failure, disk error or forced shutdown can leave an incomplete archive; automatic recovery/continuing recording after a network failure is not implemented.

## Live preview and meters

Record, Replay and Live Stream now request an optional 640×360 JPEG preview at up to 5 FPS from the same portal video source. A leaky queue isolates the preview branch from the encoder; the Qt image provider keeps only the current image in memory. No preview images are saved to disk. The frame and audio meters clear when the helper exits. System audio and microphone meters use pre-mix peak levels normalized across -60 to 0 dBFS; these indicate signal activity, not calibrated loudness. Unselected audio inputs remain at zero. Preview needs jpegenc/appsink/level; capture continues without it if those optional plugins are unavailable.

Generated-source tests verify JPEG frames, bounded queue/rate, both meter messages and successful recording finalization. Real desktop preview and external service delivery still need interactive verification.
