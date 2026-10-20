# Capture audio mixer

> **Redline** is an independent, open-source alternative to **AMD Software: Adrenalin Edition** for Linux. This page documents one part of the native Linux implementation; features and parity depend on hardware, drivers and desktop support. [Project overview](../README.md).

Record & Stream → Settings and Live Stream share device, volume and mute preferences.
Enable system audio and/or microphone, refresh the device list and choose a device. System audio lists output monitors; microphone lists input sources. System default follows the audio server default. Named selections are validated before capture and checked every two seconds during capture. A missing named device stops capture instead of deliberately selecting another source. Audio-server automatic routing and physical unplug behavior still need hardware validation.

Use **Test audio — no recording** to open only enabled sources and view post-volume/post-mute level meters. No screen portal, playback or output file is involved. Stop the test before recording/streaming. Devices can be changed only while stopped. Volume (0–100%) and mute can change live; these affect Redline's mix, not system device volume. Muting does not release the source; Stop releases it.

Both inputs are mixed into one audio track. Reduce gains if the combined signal clips. Separate microphone tracks, application-specific loopback and noise suppression remain future work. A device error stops capture; finalization is attempted on detected removal, but driver errors can leave incomplete files.

The GStreamer PulseAudio provider works with PulseAudio and PipeWire-Pulse. Enumeration reads device metadata and never transitions an audio source to PLAYING. Capture/preview is blocked in the read-only AppImage Preview.

Validation: generated 440/880 Hz sources exercise gain, mute, post-gain meters, live changes and recording integration. Missing/wrong-role device selections are rejected. The desktop device metadata was enumerated; no physical microphone or output monitor was opened for automated tests.
