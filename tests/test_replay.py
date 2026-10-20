# SPDX-License-Identifier: GPL-3.0-or-later
"""Generated sources only: rolling segments, export, retention and cleanup."""
import importlib.util
import pathlib
import shutil
import subprocess
import tempfile
import types
import unittest
spec=importlib.util.spec_from_file_location('capture',pathlib.Path(__file__).parents[1]/'tools/redline-capture.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

@unittest.skipUnless(shutil.which('ffmpeg'),'ffmpeg required')
class ReplayTests(unittest.TestCase):
 def test_bounded_buffer_export_and_cleanup(self):
  with tempfile.TemporaryDirectory() as folder:
   recorder=capture.Recorder(types.SimpleNamespace(replay_seconds=15,output=str(pathlib.Path(folder)/'unused.webm')))
   temp=pathlib.Path(recorder.replay_dir.name)
   pipeline=capture.make_pipeline(str(temp/'chunk-%06d.webm'),synthetic=True,replay=True,audio=True,resolution='720p')
   recorder.pipeline=pipeline
   pipeline.get_by_name('screen').set_property('num-buffers',660)
   pipeline.get_by_name('system-audio').set_property('num-buffers',1100)
   bus=pipeline.get_bus();pipeline.set_state(capture.Gst.State.PLAYING)
   try:
    while True:
     msg=bus.timed_pop_filtered(30*capture.Gst.SECOND,capture.Gst.MessageType.ERROR|capture.Gst.MessageType.ELEMENT|capture.Gst.MessageType.EOS)
     self.assertIsNotNone(msg)
     self.assertNotEqual(msg.type,capture.Gst.MessageType.ERROR,msg.parse_error() if msg.type==capture.Gst.MessageType.ERROR else '')
     recorder.bus_message(bus,msg)
     if len(recorder.fragments)==3 and recorder.export_thread is None:
      recorder.save_replay()
     if msg.type==capture.Gst.MessageType.EOS:break
    self.assertGreater(len(recorder.fragments),1)
    self.assertLessEqual(len(recorder.fragments),7)
    recorder.export_thread.join(30)
    recorder.save_replay();recorder.export_thread.join(30)
    self.assertFalse(recorder.export_thread.is_alive())
    output=list(pathlib.Path(folder).glob('Replay-*.webm'));self.assertEqual(len(output),2)
    for clip in output:
     subprocess.run(['ffmpeg','-v','error','-i',str(clip),'-f','null','-'],check=True,timeout=30)
    self.assertEqual(len(list(temp.glob('*.webm'))),len(recorder.fragments))
   finally:
    pipeline.set_state(capture.Gst.State.NULL);recorder.replay_dir.cleanup()
   self.assertFalse(temp.exists())

if __name__=='__main__':unittest.main()
