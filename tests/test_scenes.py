# SPDX-License-Identifier: GPL-3.0-or-later
"""Generated overlay pixels must reach both preview and encoded video."""
import importlib.util
import pathlib
import shutil
import subprocess
import tempfile
import unittest
import gi
gi.require_version('GdkPixbuf','2.0')
from gi.repository import GdkPixbuf
spec=importlib.util.spec_from_file_location('capture',pathlib.Path(__file__).parents[1]/'tools/redline-capture.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

class SceneTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('ffmpeg') and capture.Gst.ElementFactory.find('gdkpixbufoverlay'),'composition and ffmpeg required')
 def test_overlay_reaches_preview_and_recording(self):
  with tempfile.TemporaryDirectory() as folder:
   overlay=pathlib.Path(folder)/'overlay.png';output=pathlib.Path(folder)/'video.webm'
   pixels=GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB,True,8,1280,720);pixels.fill(0)
   pixels.new_subpixbuf(0,0,320,180).fill(0xff0000ff);pixels.savev(str(overlay),'png',[],[])
   frames=[];pipeline=capture.make_pipeline(str(output),synthetic=True,resolution='720p',preview=True,on_preview=frames.append,overlay_file=str(overlay));pipeline.get_by_name('screen').set_property('pattern',2)
   try:
    pipeline.set_state(capture.Gst.State.PLAYING)
    message=pipeline.get_bus().timed_pop_filtered(20*capture.Gst.SECOND,capture.Gst.MessageType.EOS|capture.Gst.MessageType.ERROR)
    self.assertIsNotNone(message);self.assertEqual(message.type,capture.Gst.MessageType.EOS,message.parse_error() if message.type==capture.Gst.MessageType.ERROR else '')
   finally:pipeline.set_state(capture.Gst.State.NULL)
   self.assertGreater(len(frames),0)
   loader=GdkPixbuf.PixbufLoader.new_with_type('jpeg');loader.write(frames[-1]);loader.close();image=loader.get_pixbuf();data=image.get_pixels();offset=10*image.get_rowstride()+10*image.get_n_channels();self.assertGreater(data[offset],200);self.assertLess(data[offset+1],40)
   raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(output),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','-'])
   offset=(10*1280+10)*3;self.assertGreater(raw[offset],200);self.assertLess(raw[offset+1],40)
   offset=(360*1280+640)*3;self.assertTrue(all(v<30 for v in raw[offset:offset+3]))

if __name__=='__main__':unittest.main()
