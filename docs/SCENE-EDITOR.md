# Scene Editor — first functional implementation

The editor follows the observed source/scene/property structure of the supplied Windows reference. This implementation supports up to 20 locally saved scenes, creation/deletion/renaming/selection, an image layer and a text layer over the portal-selected screen/window. A master Use scene for capture switch is off by default. It applies to Record, Replay, Custom Live Stream and its archive.

Select an image or text source, then click the canvas or use X/Y controls to position it. Image width, text size, opacity and text-above-image order are editable. PNG/JPEG inputs are limited to 20 MiB and 16 megapixels; invalid images produce an editor/capture error. Text is limited to 200 characters. The 1280×720 transparent design canvas is scaled to the selected output. Use 720p/1080p for matching 16:9 proportions; other aspect ratios stretch the design. The screen base is represented by a labelled placeholder until capture starts.

Qt paints the selected overlays once into a private temporary PNG at capture start. The same overlay is composited into the video before both the preview and encoder branches. The temporary PNG is removed after helper exit. The editor preview uses an in-memory PNG, not a screenshot of the user's desktop. Editing is disabled during capture; changes apply on the next capture.

Camera input, arbitrary numbers of sources, drag handles, rotation/cropping, changing the base screen's geometry, animated media and live scene switching remain pending. No scene automatically starts recording or streaming.

Validation: generated red-overlay pixels were checked in the JPEG preview and the encoded recording. The Qt renderer test covers image placement/opacity, transparent background, invalid inputs and Greek text. Native UI tests cover create/select/delete and the snapshot used by capture; streaming/archive/replay regression tests also passed. Real desktop scene recording still needs interactive verification.

Composition uses the documented [GStreamer gdkpixbufoverlay](https://gstreamer.freedesktop.org/documentation/gdkpixbuf/gdkpixbufoverlay.html) interface.
