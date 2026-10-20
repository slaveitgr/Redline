# SPDX-License-Identifier: GPL-3.0-or-later
import base64
import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('screenshot',Path(__file__).parents[1]/'tools/redline-screenshot.py')
shot=importlib.util.module_from_spec(spec);spec.loader.exec_module(shot)

class ScreenshotTests(unittest.TestCase):
 def test_owned_png_copy_without_screen_capture(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);source=root/'portal.png'
   source.write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII='))
   with patch.object(shot.GLib,'get_user_special_dir',return_value=str(root/'Pictures')):
    output=Path(shot.save_image(source.as_uri()))
   self.assertEqual(output.read_bytes(),source.read_bytes())
   self.assertEqual(output.parent,root/'Pictures/Redline')
   self.assertEqual(stat.S_IMODE(output.stat().st_mode),0o600)
 def test_invalid_result_rejected(self):
  with tempfile.TemporaryDirectory() as directory:
   text=Path(directory)/'text';text.write_text('not an image');link=Path(directory)/'link';link.symlink_to(text)
   for uri in [text.as_uri(),link.as_uri(),'https://example.invalid/image.png']:
    with self.assertRaises(ValueError):shot.save_image(uri)
 def test_preview_rejects_before_portal(self):
  result=subprocess.run(['/usr/bin/python3',str(Path(shot.__file__))],env=dict(os.environ,REDLINE_READ_ONLY='1'),capture_output=True,text=True)
  self.assertNotEqual(result.returncode,0);self.assertIn('disabled in UI preview',result.stdout)
if __name__=='__main__':unittest.main()
