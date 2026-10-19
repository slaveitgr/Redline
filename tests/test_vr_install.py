# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('vr_install', Path(__file__).parents[1] / 'tools/redline-vr-install.py')
vr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vr)

def archive(name='alvr_launcher', link=False):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w:gz') as tar:
        item = tarfile.TarInfo(name)
        if link:
            item.type = tarfile.SYMTYPE
            item.linkname = '/etc/passwd'
            tar.addfile(item)
        else:
            body = b'fixture only; never executed'
            item.size = len(body)
            tar.addfile(item, io.BytesIO(body))
    return stream.getvalue()

class Response(io.BytesIO):
    url = 'https://release-assets.githubusercontent.com/fixture'

class InstallerTests(unittest.TestCase):
    def test_atomic_official_release_install(self):
        body = archive('alvr_launcher_linux/ALVR Launcher')
        digest = hashlib.sha256(body).hexdigest()
        release = {'tag_name': 'test', 'assets': [{'name': 'alvr_launcher_linux.tar.gz', 'digest': 'sha256:' + digest, 'size': len(body), 'browser_download_url': 'https://github.com/alvr-org/ALVR/releases/download/test/alvr_launcher_linux.tar.gz'}]}
        with tempfile.TemporaryDirectory() as folder, patch.object(vr.urllib.request, 'urlopen', side_effect=[Response(json.dumps(release).encode()), Response(body)]), patch.object(vr, 'notify'):
            vr.install(folder)
            root = Path(folder) / 'alvr'
            self.assertTrue((root / 'alvr_launcher_linux/ALVR Launcher').is_file())
            self.assertEqual(json.loads((root / 'redline-install.json').read_text())['sha256'], digest)
            self.assertEqual(list(Path(folder).glob('.alvr-install-*')), [])

    def test_legacy_name_and_ambiguity(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'alvr_launcher').write_text('fixture')
            self.assertEqual(vr.find_launcher(root).name, 'alvr_launcher')
            (root / 'ALVR Launcher').write_text('fixture')
            with self.assertRaises(ValueError):
                vr.find_launcher(root)

    def test_corrupt_download_never_published(self):
        body = archive()
        release = {'assets': [{'name': 'alvr_launcher_linux.tar.gz', 'digest': 'sha256:' + '0' * 64, 'size': len(body), 'browser_download_url': 'https://github.com/alvr-org/ALVR/releases/download/test/alvr_launcher_linux.tar.gz'}]}
        with tempfile.TemporaryDirectory() as folder, patch.object(vr.urllib.request, 'urlopen', side_effect=[Response(json.dumps(release).encode()), Response(body)]), patch.object(vr, 'notify'):
            with self.assertRaises(ValueError):
                vr.install(folder)
            self.assertFalse((Path(folder) / 'alvr').exists())

    def test_paths_and_links_rejected(self):
        for name, link in [('../escape', False), ('/absolute', False), ('link', True)]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as folder:
                source = Path(folder) / 'bad.tar.gz'
                source.write_bytes(archive(name, link))
                with self.assertRaises(ValueError):
                    vr.unpack(source, Path(folder) / 'out')

if __name__ == '__main__':
    unittest.main()
