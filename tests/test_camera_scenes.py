# SPDX-License-Identifier: GPL-3.0-or-later
"""Generated camera/screen sources only. No physical camera access."""
import importlib.util
import pathlib
import tempfile
import types
import unittest
import os
import time
import subprocess
import shutil
import io
import contextlib
import gi
gi.require_version('GdkPixbuf','2.0')
from gi.repository import GdkPixbuf
spec=importlib.util.spec_from_file_location('capture',pathlib.Path(__file__).parents[1]/'tools/redline-capture.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

class CameraSceneTests(unittest.TestCase):
 def test_camera_preview_generated_only(self):
  frames=[];pipeline=capture.camera_preview_pipeline({'resolution':'auto'},synthetic=True,on_preview=frames.append)
  try:
   pipeline.set_state(capture.Gst.State.PLAYING);message=pipeline.get_bus().timed_pop_filtered(15*capture.Gst.SECOND,capture.Gst.MessageType.EOS|capture.Gst.MessageType.ERROR)
   self.assertIsNotNone(message);self.assertEqual(message.type,capture.Gst.MessageType.EOS,message.parse_error() if message.type==capture.Gst.MessageType.ERROR else '')
   self.assertGreater(len(frames),0)
  finally:pipeline.set_state(capture.Gst.State.NULL)
 def test_camera_composition_and_live_scene_changes(self):
  with tempfile.TemporaryDirectory() as folder:
   base=pathlib.Path(folder);overlay=base/'overlay.png';next_overlay=base/'overlay-00000001.png'
   image=GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB,True,8,1280,720);image.fill(0);image.savev(str(overlay),'png',[],[]);image.fill(0x0000ffff);image.savev(str(next_overlay),'png',[],[])
   frames=[];camera={'enabled':True,'x':0,'y':0,'width':.25,'height':.25,'opacity':1}
   pipeline=capture.make_pipeline(str(base/'camera.webm'),synthetic=True,synthetic_camera=True,camera=camera,overlay_file=str(overlay),preview=True,on_preview=frames.append,resolution='720p')
   pipeline.get_by_name('screen').set_property('pattern',2)
   pipeline.get_by_name('screen').set_property('num-buffers',120)
   pipeline.get_by_name('screen').set_property('is-live',True)
   pipeline.get_by_name('camera-source').set_property('is-live',True)
   recorder=object.__new__(capture.Recorder);recorder.pipeline=pipeline;recorder.args=types.SimpleNamespace(overlay_file=str(overlay),camera=camera)
   try:
    pipeline.set_state(capture.Gst.State.PLAYING);bus=pipeline.get_bus();switched=False
    deadline=time.monotonic()+12
    while time.monotonic()<deadline:
     message=bus.timed_pop_filtered(capture.Gst.SECOND//10,capture.Gst.MessageType.EOS|capture.Gst.MessageType.ERROR|capture.Gst.MessageType.STATE_CHANGED)
     if message is None:
      if len(frames)>=3 and not switched:
       recorder.apply_scene({'command':'scene','serial':1,'overlay':str(next_overlay),'camera':dict(camera,enabled=False)});switched=True
      continue
     self.assertNotEqual(message.type,capture.Gst.MessageType.ERROR,message.parse_error() if message.type==capture.Gst.MessageType.ERROR else '')
     if message.type==capture.Gst.MessageType.EOS:break
    self.assertTrue(switched);self.assertGreater(len(frames),3);self.assertGreater((base/'camera.webm').stat().st_size,1000)
    def pixel(data):
     loader=GdkPixbuf.PixbufLoader.new_with_type('jpeg');loader.write(data);loader.close();picture=loader.get_pixbuf();offset=45*picture.get_rowstride()+80*picture.get_n_channels();return picture.get_pixels()[offset:offset+3]
    before=[pixel(f) for f in frames[:3]];after=pixel(frames[-1]);self.assertTrue(any(v[0]>200 and v[2]<40 for v in before),str(before));self.assertGreater(after[2],200);self.assertLess(after[0],40)
    self.assertEqual(pipeline.get_by_name('scene-compositor').get_static_pad('sink_1').get_property('alpha'),0)
    if shutil.which('ffmpeg'):subprocess.run(['ffmpeg','-v','error','-i',str(base/'camera.webm'),'-f','null','-'],check=True,timeout=15)
   finally:pipeline.set_state(capture.Gst.State.NULL)
 def test_multiple_commands_in_one_read(self):
  recorder=object.__new__(capture.Recorder);recorder.command_buffer=b'';recorder.stopping=False;seen=[];recorder.apply_scene=lambda item:seen.append(item['serial']);recorder.replay_dir=None
  read,write=os.pipe();os.write(write,b'{"command":"scene","serial":1}\n{"command":"scene","serial":2}\n');os.close(write)
  with os.fdopen(read,'rb',buffering=0) as stream:recorder.command(stream,capture.GLib.IO_IN)
  self.assertEqual(seen,[1,2])
 def test_partial_scene_command_waits_for_newline(self):
  recorder=object.__new__(capture.Recorder);recorder.command_buffer=b'';recorder.stopping=False;seen=[];recorder.apply_scene=lambda item:seen.append(item['serial']);recorder.replay_dir=None
  read,write=os.pipe()
  with os.fdopen(read,'rb',buffering=0) as stream:
   os.write(write,b'{"command":"scene",');recorder.command(stream,capture.GLib.IO_IN);self.assertEqual(seen,[])
   os.write(write,b'"serial":3}\n');recorder.command(stream,capture.GLib.IO_IN);self.assertEqual(seen,[3]);os.close(write)
 def test_camera_preview_blocked_in_read_only_mode(self):
  env=dict(os.environ,REDLINE_READ_ONLY='1')
  result=subprocess.run(['python3',str(pathlib.Path(__file__).parents[1]/'tools/redline-capture.py'),'--camera-preview','--camera-device','/dev/video0'],capture_output=True,text=True,env=env,timeout=5)
  self.assertNotEqual(result.returncode,0);self.assertIn('disabled in UI preview',result.stderr)
 def test_disabled_camera_does_not_create_a_camera_source(self):
  with tempfile.TemporaryDirectory() as folder:
   pipeline=capture.make_pipeline(str(pathlib.Path(folder)/'unused.webm'),synthetic=True,camera={'enabled':False,'device':'/dev/null'})
   self.assertIsNone(pipeline.get_by_name('camera-source'));pipeline.set_state(capture.Gst.State.NULL)
 def test_stream_config_does_not_consume_following_stop(self):
  read,write=os.pipe();os.write(write,b'{"server":"fixture"}\nstop\n');os.close(write)
  try:
   self.assertEqual(capture.read_initial_config(read),{'server':'fixture'});self.assertEqual(os.read(read,20),b'stop\n')
  finally:os.close(read)
 def test_non_camera_paths_rejected(self):
  for device in ('/dev/null','/etc/passwd','/dev/video0/../null','remote://camera'):
   with self.assertRaises(ValueError):capture.camera_config({'device':device})

if __name__=='__main__':unittest.main()
