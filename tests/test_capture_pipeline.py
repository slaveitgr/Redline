# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise real encoders without capturing a desktop or microphone."""
import importlib.util
import pathlib
import tempfile
import unittest
spec = importlib.util.spec_from_file_location('capture', pathlib.Path(__file__).parents[1] / 'tools/redline-capture.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


class CaptureTests(unittest.TestCase):
    def test_video_and_optional_audio_finalize(self):
        with tempfile.TemporaryDirectory() as folder:
            for audio in (False, True):
                with self.subTest(audio=audio):
                    output = pathlib.Path(folder) / f'{audio}.webm'
                    pipeline = capture.make_pipeline(str(output), 30, audio, synthetic=True)
                    try:
                        pipeline.set_state(capture.Gst.State.PLAYING)
                        message = pipeline.get_bus().timed_pop_filtered(15*capture.Gst.SECOND,
                            capture.Gst.MessageType.ERROR | capture.Gst.MessageType.EOS)
                        self.assertIsNotNone(message)
                        self.assertEqual(message.type, capture.Gst.MessageType.EOS,
                            message.parse_error() if message.type == capture.Gst.MessageType.ERROR else '')
                    finally:
                        pipeline.set_state(capture.Gst.State.NULL)
                    self.assertGreater(output.stat().st_size, 1000)
                    self.assertEqual(output.read_bytes()[:4], b'\x1a\x45\xdf\xa3')


if __name__ == '__main__':
    unittest.main()
