# SPDX-License-Identifier: GPL-3.0-or-later
"""Generated frames and audio only; no portal/device access."""
import importlib.util
import pathlib
import tempfile
import subprocess
import shutil
import unittest
spec=importlib.util.spec_from_file_location('capture',pathlib.Path(__file__).parents[1]/'tools/redline-capture.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

class PreviewTests(unittest.TestCase):
 def test_preview_and_meters_preserve_recording(self):
  frames=[];levels=set()
  with tempfile.TemporaryDirectory() as folder:
   output=pathlib.Path(folder)/'recording.webm'
   pipeline=capture.make_pipeline(str(output),synthetic=True,preview=True,on_preview=frames.append,audio=True,microphone=True)
   try:
    pipeline.set_state(capture.Gst.State.PLAYING);bus=pipeline.get_bus()
    while True:
     msg=bus.timed_pop_filtered(15*capture.Gst.SECOND,capture.Gst.MessageType.EOS|capture.Gst.MessageType.ERROR|capture.Gst.MessageType.ELEMENT)
     self.assertIsNotNone(msg)
     self.assertNotEqual(msg.type,capture.Gst.MessageType.ERROR,msg.parse_error() if msg.type==capture.Gst.MessageType.ERROR else '')
     if msg.type==capture.Gst.MessageType.EOS:break
     structure=msg.get_structure()
     if structure and structure.get_name()=='level':
      peaks=structure.get_value('peak');self.assertTrue(len(peaks)>0);self.assertGreater(max(peaks),-60);levels.add(msg.src.get_name())
    self.assertGreater(len(frames),1);self.assertLessEqual(len(frames),10)
    self.assertTrue(all(f[:2]==b'\xff\xd8' and len(f)<=200000 for f in frames))
    self.assertEqual(levels,{'system-level','microphone-level'})
    self.assertGreater(output.stat().st_size,1000)
    if shutil.which('ffmpeg'):
     subprocess.run(['ffmpeg','-v','error','-i',str(output),'-f','null','-'],check=True,timeout=15)
    self.assertEqual(pipeline.get_by_name('preview-queue').get_property('max-size-buffers'),1)
   finally:pipeline.set_state(capture.Gst.State.NULL)

if __name__=='__main__':unittest.main()
