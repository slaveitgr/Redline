# SPDX-License-Identifier: GPL-3.0-or-later
"""Real encode/mux tests using generated sources; no desktop or microphone capture."""
import importlib.util
import pathlib
import tempfile
import unittest
spec = importlib.util.spec_from_file_location('capture', pathlib.Path(__file__).parents[1] / 'tools/redline-capture.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


class CaptureTests(unittest.TestCase):
    def encode(self, output, **options):
        pipeline = capture.make_pipeline(str(output), synthetic=True, **options)
        try:
            pipeline.set_state(capture.Gst.State.PLAYING)
            message = pipeline.get_bus().timed_pop_filtered(30*capture.Gst.SECOND,
                capture.Gst.MessageType.ERROR | capture.Gst.MessageType.EOS)
            self.assertIsNotNone(message)
            self.assertEqual(message.type, capture.Gst.MessageType.EOS,
                message.parse_error() if message.type == capture.Gst.MessageType.ERROR else '')
            caps = pipeline.get_by_name('video-encoder').get_static_pad('src').get_current_caps().get_structure(0)
            self.assertGreater(output.stat().st_size, 1000)
            return caps, pipeline
        finally:
            pipeline.set_state(capture.Gst.State.NULL)

    def test_available_encoders_and_audio_combinations(self):
        with tempfile.TemporaryDirectory() as folder:
            for codec in capture.available_codecs():
                for system, microphone in ((False,False),(True,False),(False,True),(True,True)):
                    with self.subTest(codec=codec['id'],system=system,microphone=microphone):
                        output = pathlib.Path(folder) / f"{codec['id']}-{system}-{microphone}.{codec['extension']}"
                        caps, pipeline = self.encode(output, codec=codec['id'], audio=system, microphone=microphone, bitrate=4)
                        self.assertEqual(caps.get_name(), {'vp8':'video/x-vp8','vp9':'video/x-vp9','h264':'video/x-h264'}[codec['id']])
                        data=output.read_bytes()
                        self.assertTrue(data[:4]==b'\x1a\x45\xdf\xa3' if codec['extension']=='webm' else data[4:8]==b'ftyp')
                        mixer=pipeline.get_by_name('audio-mixer')
                        self.assertEqual(len(mixer.sinkpads) if mixer else 0, int(system)+int(microphone))

    def test_resolution_and_bitrate_are_applied(self):
        with tempfile.TemporaryDirectory() as folder:
            caps,pipeline=self.encode(pathlib.Path(folder)/'scaled.webm',resolution='720p',bitrate=12)
            self.assertEqual(caps.get_value('width'),1280)
            self.assertEqual(caps.get_value('height'),720)
            self.assertEqual(pipeline.get_by_name('video-encoder').get_property('target-bitrate'),12_000_000)

    def test_invalid_configuration_rejected_before_pipeline(self):
        for options in ({'codec':'shell-command'}, {'resolution':'99999x99999'}, {'bitrate':0}, {'bitrate':1000}, {'fps':999}):
            with self.assertRaises(ValueError):capture.make_pipeline('/tmp/unused-redline.webm',synthetic=True,**options)


if __name__ == '__main__':
    unittest.main()
