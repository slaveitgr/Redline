# SPDX-License-Identifier: GPL-3.0-or-later
"""Loopback RTMP tests with generated content; no screen/audio device access."""
import importlib.util
import json
import contextlib
import io
import types
import os
import pathlib
import shutil
import socket
import subprocess
import tempfile
import time
import threading
import unittest
spec=importlib.util.spec_from_file_location('capture',pathlib.Path(__file__).parents[1]/'tools/redline-capture.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

class StreamingTests(unittest.TestCase):
 def test_destination_validation(self):
  for server,key in [('https://example.com/live','secret'),('rtmp://name:password@example.com/live','secret'),('rtmp://example.com/live?key=secret','secret'),('rtmp://example.com/','key'),('rtmp://example.com:99999/live','key'),('rtmp://example.com/live','a\nstop'),('rtmp://example.com/live','')]:
   with self.assertRaises(ValueError):capture.stream_location(server,key)
  self.assertEqual(capture.stream_location('rtmps://example.com:443/live','secret/key'),'rtmps://example.com:443/live/secret%2Fkey')
 def test_preview_blocks_before_reading_credentials_or_portal(self):
  env=dict(os.environ,REDLINE_READ_ONLY='1')
  p=subprocess.run(['python3',str(pathlib.Path(__file__).parents[1]/'tools/redline-capture.py'),'--stream','--codec','h264'],input='',text=True,capture_output=True,env=env,timeout=5)
  self.assertNotEqual(p.returncode,0);self.assertIn('disabled in UI preview',p.stderr)
 def test_stream_error_redacts_credentials(self):
  recorder=object.__new__(capture.Recorder)
  recorder.args=types.SimpleNamespace(stream=True)
  recorder.failed=False;recorder.loop=capture.GLib.MainLoop();recorder.replay_dir=None
  error=capture.GLib.Error.new_literal(capture.Gst.ResourceError.quark(),'rtmp://example/live/PRIVATE-KEY',int(capture.Gst.ResourceError.WRITE))
  message=capture.Gst.Message.new_error(None,error,'PRIVATE-KEY')
  stdout,stderr=io.StringIO(),io.StringIO()
  with contextlib.redirect_stdout(stdout),contextlib.redirect_stderr(stderr):recorder.bus_message(None,message)
  self.assertTrue(recorder.failed);self.assertNotIn('PRIVATE-KEY',stdout.getvalue()+stderr.getvalue())
 @unittest.skipUnless(capture.streaming_supported(),'RTMP/H264/AAC required')
 def test_unreachable_server_fails_in_bounded_time(self):
  with socket.socket() as sock:
   sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
   endpoint=capture.stream_location(f'rtmp://127.0.0.1:{port}/live','test-only')
   pipeline=capture.make_pipeline(None,synthetic=True,codec='h264',stream=endpoint)
   try:
    pipeline.set_state(capture.Gst.State.PLAYING)
    message=pipeline.get_bus().timed_pop_filtered(12*capture.Gst.SECOND,capture.Gst.MessageType.ERROR)
    self.assertIsNotNone(message)
   finally:pipeline.set_state(capture.Gst.State.NULL)
 @unittest.skipUnless(shutil.which('ffmpeg') and shutil.which('ffprobe') and capture.streaming_supported(),'RTMP/H264/AAC and ffmpeg required')
 def test_loopback_video_and_audio(self):
  self.receive(False)
 def test_loopback_stream_and_archive(self):
  self.receive(True)
 def receive(self,archive):
  if not (shutil.which("ffmpeg") and shutil.which("ffprobe") and capture.streaming_supported()):self.skipTest("Streaming dependencies required")
  with tempfile.TemporaryDirectory() as folder:
   output=pathlib.Path(folder)/'received.flv'
   with socket.socket() as sock:
    sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
   endpoint=capture.stream_location(f'rtmp://127.0.0.1:{port}/live','test-only')
   receiver=subprocess.Popen(['ffmpeg','-nostdin','-v','error','-listen','1','-i',endpoint,'-c','copy','-y',str(output)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
   pipeline=None;stop_timer=None
   try:
    time.sleep(.4)
    self.assertIsNone(receiver.poll(),'Local RTMP receiver failed to start')
    local=pathlib.Path(folder)/'archive.mp4'
    pipeline=capture.make_pipeline(str(local) if archive else None,synthetic=True,codec='h264',audio=True,stream=endpoint,audio_bitrate=192,resolution='720p',bitrate=3,archive=archive)
    pipeline.get_by_name('screen').set_property('num-buffers',120)
    pipeline.get_by_name('system-audio').set_property('num-buffers',190)
    if archive:
     elements=[];iterator=pipeline.iterate_elements()
     while True:
      status,element=iterator.next()
      if status==capture.Gst.IteratorResult.DONE:break
      self.assertEqual(status,capture.Gst.IteratorResult.OK)
      elements.append(element)
     self.assertEqual(sum(e.get_factory().get_name()=='x264enc' for e in elements),1)
     self.assertEqual(sum(e.get_factory().get_name()=='avenc_aac' for e in elements),1)
     for name in ('screen','system-audio'):
      source=pipeline.get_by_name(name);source.set_property('num-buffers',-1);source.set_property('is-live',True)
     stop_timer=threading.Timer(4,lambda:pipeline.send_event(capture.Gst.Event.new_eos()))
     stop_timer.start()
    pipeline.set_state(capture.Gst.State.PLAYING)
    message=pipeline.get_bus().timed_pop_filtered(30*capture.Gst.SECOND,capture.Gst.MessageType.ERROR|capture.Gst.MessageType.EOS)
    self.assertIsNotNone(message);self.assertEqual(message.type,capture.Gst.MessageType.EOS,message.parse_error() if message.type==capture.Gst.MessageType.ERROR else '')
    pipeline.set_state(capture.Gst.State.NULL)
    receiver.communicate(timeout=10)
    if archive:
     local_probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(local)]))
     self.assertEqual({s['codec_name'] for s in local_probe['streams']},{'h264','aac'})
     self.assertGreater(float(local_probe['format']['duration']),3)
     subprocess.run(['ffmpeg','-v','error','-i',str(local),'-f','null','-'],check=True,timeout=15)
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(output)]))
    self.assertEqual({s['codec_name'] for s in probe['streams']},{'h264','aac'})
    video=next(s for s in probe['streams'] if s['codec_type']=='video');self.assertEqual((video['width'],video['height']),(1280,720))
    subprocess.run(['ffmpeg','-v','error','-i',str(output),'-f','null','-'],check=True,timeout=15)
   finally:
    if stop_timer:stop_timer.cancel()
    if pipeline:pipeline.set_state(capture.Gst.State.NULL)
    if receiver.poll() is None:receiver.terminate();receiver.communicate(timeout=5)

if __name__=='__main__':unittest.main()
