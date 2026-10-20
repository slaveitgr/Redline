# SPDX-License-Identifier: GPL-3.0-or-later
"""Generated audio only; no microphone, output monitor or portal access."""
import importlib.util
import pathlib
import tempfile
import unittest
import math
import subprocess
import os
import types
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('capture',pathlib.Path(__file__).parents[1]/'tools/redline-capture.py')
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
class AudioTests(unittest.TestCase):
 def test_missing_device_refuses_fallback(self):
  config=c.audio_settings({'microphoneDevice':'missing'})
  with self.assertRaisesRegex(ValueError,'unavailable'):c.validate_audio_devices(config,False,True,[])
  c.validate_audio_devices(config,False,False,[])
 def test_wrong_device_role(self):
  with self.assertRaises(ValueError):c.validate_audio_devices(c.audio_settings({'systemDevice':'mic'}),True,False,[{'id':'mic','kind':'microphone'}])
 def test_invalid_settings(self):
  for value in [-1,1.01,math.nan,math.inf]:
   with self.assertRaises(ValueError):c.audio_settings({'systemVolume':value})
  with self.assertRaises(ValueError):c.audio_settings({'systemMute':'false'})
 def test_sources_use_explicit_devices_without_starting(self):
  p=c.audio_preview_pipeline(True,True,{'systemDevice':'test.monitor','microphoneDevice':'test.mic'})
  self.assertEqual(p.get_by_name('system-audio').get_property('device'),'test.monitor')
  self.assertEqual(p.get_by_name('microphone-audio').get_property('device'),'test.mic')
  self.assertIsNone(p.get_by_name('filesink'))
 def test_generated_levels_mute_and_live_volume(self):
  p=c.audio_preview_pipeline(True,True,{'systemMute':True,'microphoneVolume':.25},synthetic=True)
  self.assertEqual(p.get_by_name('microphone-volume').get_property('volume'),.25)
  try:
   p.set_state(c.Gst.State.PLAYING);seen={}
   while True:
    m=p.get_bus().timed_pop_filtered(10*c.Gst.SECOND,c.Gst.MessageType.EOS|c.Gst.MessageType.ERROR|c.Gst.MessageType.ELEMENT)
    self.assertIsNotNone(m);self.assertNotEqual(m.type,c.Gst.MessageType.ERROR)
    if m.type==c.Gst.MessageType.EOS:break
    s=m.get_structure()
    if s and s.get_name()=='level':seen[m.src.get_name()]=max(s.get_value('peak'))
   self.assertLess(seen['system-level'],-100);self.assertGreater(seen['microphone-level'],-50)
   c.apply_audio(p,{'systemVolume':.4,'microphoneMute':True})
   self.assertAlmostEqual(p.get_by_name('system-volume').get_property('volume'),.4)
   self.assertTrue(p.get_by_name('microphone-volume').get_property('mute'))
  finally:p.set_state(c.Gst.State.NULL)
 def test_recording_uses_same_mixer(self):
  with tempfile.TemporaryDirectory() as d:
   p=c.make_pipeline(str(pathlib.Path(d)/'a.webm'),synthetic=True,audio=True,microphone=True,audio_config={'systemVolume':.3,'microphoneMute':True})
   self.assertAlmostEqual(p.get_by_name('system-volume').get_property('volume'),.3)
   self.assertTrue(p.get_by_name('microphone-volume').get_property('mute'))
 def test_readonly_preview_does_not_open_sources(self):
  env=os.environ.copy();env['REDLINE_READ_ONLY']='1'
  result=subprocess.run(['/usr/bin/python3',str(pathlib.Path(c.__file__)),'--audio-preview','--microphone'],env=env,capture_output=True,text=True,timeout=5)
  self.assertNotEqual(result.returncode,0);self.assertIn('disabled in UI preview',result.stderr)
 def test_disconnection_requests_finalization(self):
  recorder=c.Recorder.__new__(c.Recorder);recorder.stopping=False;recorder.failed=False
  recorder.args=types.SimpleNamespace(audio_config={'microphoneDevice':'disconnected'},audio=False,microphone=True)
  stopped=[];recorder.stop=lambda:stopped.append(True)
  with patch.object(c,'validate_audio_devices',side_effect=ValueError('missing')):
   self.assertFalse(recorder.check_audio_devices())
  self.assertEqual(stopped,[True]);self.assertIn('disconnected',recorder.audio_failure)
 def test_preview_requires_source(self):
  with self.assertRaises(ValueError):c.audio_preview_pipeline(False,False,synthetic=True)
if __name__=='__main__':unittest.main()
