# Scene Editor — first functional implementation

> **Redline** is an independent, open-source alternative to **AMD Software: Adrenalin Edition** for Linux. This page documents one part of the native Linux implementation; features and parity depend on hardware, drivers and desktop support. [Project overview](../README.md).

The editor follows the observed source/scene/property structure of the supplied Windows reference. This implementation supports up to 20 locally saved scenes, creation/deletion/renaming/selection, an image layer and a text layer over the portal-selected screen/window. A master Use scene at capture start switch is off by default. It applies to Record, Replay, Custom Live Stream and its archive.

Select an image or text source, then click the canvas or use X/Y controls to position it. Image width, text size, opacity and text-above-image order are editable. PNG/JPEG inputs are limited to 20 MiB and 16 megapixels; invalid images produce an editor/capture error. Text is limited to 200 characters. The 1280×720 transparent design canvas is scaled to the selected output. Use 720p/1080p for matching 16:9 proportions; other aspect ratios stretch the design. The screen base is represented by a labelled placeholder until capture starts.

Qt paints the selected overlays once into a private temporary PNG at capture start. The same overlay is composited into the video before both the preview and encoder branches. The temporary PNG is removed after helper exit. The editor preview uses an in-memory PNG, not a screenshot of the user's desktop. Source editing is disabled during capture; saved scenes can be applied live.

Arbitrary numbers of sources, drag handles, rotation/cropping, changing the base screen's geometry and animated media remain pending. No scene automatically starts recording or streaming.

Validation: generated red-overlay pixels were checked in the JPEG preview and the encoded recording. The Qt renderer test covers image placement/opacity, transparent background, invalid inputs and Greek text. Native UI tests cover create/select/delete and the snapshot used by capture; streaming/archive/replay regression tests also passed. Real desktop scene recording still needs interactive verification.

Composition uses the documented [GStreamer gdkpixbufoverlay](https://gstreamer.freedesktop.org/documentation/gdkpixbuf/gdkpixbufoverlay.html) interface.

## Camera and live scene switching

The Camera source lists local /dev/videoN nodes by reading sysfs names; enumeration does not open devices. Linux V4L2 cameras can be previewed explicitly without recording, then enabled in a scene for capture. Input resolution choices are auto, 640×480 and 1280×720; actual support depends on the selected camera. Camera position, bounding width/height and opacity are stored per scene. Aspect ratio is preserved inside the camera bounds. The camera is composed over the screen and below image/text overlays.

Select Use scene at capture start and Use camera in capture before starting to include the device. Stop the camera-only preview before starting a recording/stream. During capture choose a saved scene and Apply selected scene live; the helper updates the overlay and camera geometry without resetting the pipeline or encoder. The camera device/resolution must match those used at startup. A camera cannot be added to an already running capture that started without it. Hiding it sets its contribution to zero; the device stays open until capture stops. Preview/capture failures release the device when the helper exits. Device permissions are not modified.

Camera-only preview and live switching are blocked in read-only Preview builds. Physical webcams, disconnect/reconnect behavior, PipeWire camera portals and external streaming services are not yet validated. Camera errors currently stop the capture; automatic recovery is pending.

Tests use generated screen/camera sources only. They check camera JPEG preview, red-camera pixels followed by a blue overlay after a live switch, final recording decode, multiple scene commands in one IPC read and invalid device paths. A loopback RTMP/MP4 test also changes camera geometry during streaming, verifies acknowledgement and fully decodes both outputs.

Implementation references: [GStreamer compositor](https://gstreamer.freedesktop.org/documentation/compositor/index.html) and [v4l2src](https://gstreamer.freedesktop.org/documentation/video4linux2/v4l2src.html).
