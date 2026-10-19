# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util, json, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('steam_options',Path(__file__).parents[1]/'tools/redline-steam-options.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class SteamOptionsTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.file=self.root/'userdata/1/config/localconfig.vdf';self.file.parent.mkdir(parents=True)
  self.original='"UserLocalConfigStore" { "Software" { "Valve" { "Steam" { "apps" { "42" { "LaunchOptions" "-novid" "Keep" "value" } "7" { "LaunchOptions" "untouched" } } } } } }';self.file.write_text(self.original)
 def run_main(self,*args,running=False):
  with patch.object(m,'steam_running',return_value=running),patch('sys.argv',['tool','--steam-root',str(self.root),'--app-id','42',*args]):m.main()
 def test_round_trip_preserves_other_game_and_options(self):
  self.run_main('--options','env REDLINE_LAUNCH=1 mangohud %command%');text=self.file.read_text();self.assertIn('%command% -novid',text);self.assertIn('"LaunchOptions" "untouched"',text);self.assertIn('"Keep" "value"',text)
  self.run_main('--restore');self.assertEqual(self.file.read_text(),self.original);self.assertTrue(list(self.file.parent.glob('*.bak')))
 def test_running_steam_refuses_mutation(self):
  with self.assertRaises(ValueError):self.run_main('--options','mangohud %command%',running=True)
  self.assertEqual(self.file.read_text(),self.original)
 def test_existing_wrapper_is_preserved(self):
  self.file.write_text(self.original.replace('-novid','custom-wrapper %command%'))
  with self.assertRaises(ValueError):self.run_main('--options','mangohud %command%')
  self.assertIn('custom-wrapper %command%',self.file.read_text())
 def test_external_edit_is_not_overwritten(self):
  self.run_main('--options','mangohud %command%');text=self.file.read_text().replace('mangohud %command% -novid','new-user-command %command%');self.file.write_text(text)
  with self.assertRaises(ValueError):self.run_main('--restore')
  self.assertEqual(self.file.read_text(),text)
 def test_new_game_is_inserted_without_touching_existing_game(self):
  changed=m.rewrite(self.original,'99','mangohud %command%');node,missing=m.locate(changed,'99');self.assertIsNone(missing);self.assertEqual(m.child(node['children'],'LaunchOptions')['value'],'mangohud %command%');self.assertIn('"LaunchOptions" "untouched"',changed)
if __name__=='__main__':unittest.main()
