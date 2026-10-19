#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Install the official ALVR launcher in Redline's user-owned data directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tarfile
import tempfile
import urllib.request

LIMIT = 256 * 1024 * 1024

def notify(message, progress=-1):
    print(json.dumps({'message': message, 'progress': progress}), flush=True)

def unpack(archive, destination):
    total = 0
    with tarfile.open(archive, 'r:gz') as source:
        members = source.getmembers()
        if len(members) > 10000:
            raise ValueError('Too many archive entries')
        for member in members:
            path = PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or not (member.isfile() or member.isdir()):
                raise ValueError('Unsafe archive entry')
            total += member.size
            if total > 1024 * 1024 * 1024:
                raise ValueError('Archive is too large')
        source.extractall(destination, members=members, filter='data')

def find_launcher(contents):
    names = {'alvr_launcher', 'ALVR Launcher'}
    launchers = [p for p in Path(contents).rglob('*') if p.name in names and p.is_file() and not p.is_symlink()]
    if len(launchers) != 1:
        raise ValueError('The ALVR launcher could not be identified in the archive.')
    return launchers[0]

def install(root):
    if os.uname().machine != 'x86_64':
        raise ValueError('The automatic ALVR launcher installer currently supports x86_64 only.')
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    destination = root / 'alvr'
    if destination.exists():
        raise ValueError('An ALVR installation already exists in Redline. Remove or review it before reinstalling.')
    notify('Checking the official ALVR release…')
    request = urllib.request.Request('https://api.github.com/repos/alvr-org/ALVR/releases/latest', headers={'User-Agent': 'Redline-VR-Installer', 'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.loads(response.read(2 * 1024 * 1024))
    assets = [item for item in release.get('assets', []) if item['name'] == 'alvr_launcher_linux.tar.gz']
    if len(assets) != 1:
        raise ValueError('The official Linux launcher asset could not be identified.')
    asset = assets[0]
    url = asset['browser_download_url']
    if not url.startswith('https://github.com/alvr-org/ALVR/releases/download/'):
        raise ValueError('Unexpected ALVR release URL')
    digest = asset.get('digest', '')
    if not digest.startswith('sha256:') or len(digest) != 71:
        raise ValueError('The release has no SHA-256 digest. Use the official installation guide.')
    size = asset.get('size', 0)
    if not 0 < size <= LIMIT:
        raise ValueError('Unsupported release size')
    with tempfile.TemporaryDirectory(prefix='.alvr-install-', dir=root) as staging:
        staging = Path(staging)
        archive = staging / 'launcher.tar.gz'
        hashed = hashlib.sha256()
        downloaded = 0
        last = -1
        with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Redline-VR-Installer'}), timeout=60) as response, archive.open('wb') as output:
            if not response.url.startswith('https://'):
                raise ValueError('Insecure download redirect')
            while block := response.read(1024 * 1024):
                downloaded += len(block)
                if downloaded > LIMIT:
                    raise ValueError('Download exceeded the size limit')
                output.write(block)
                hashed.update(block)
                percent = min(95, downloaded * 95 // size)
                if percent != last:
                    notify('Downloading the official ALVR launcher…', percent)
                    last = percent
        if downloaded != size or hashed.hexdigest() != digest[7:]:
            raise ValueError('The ALVR download failed its SHA-256 check.')
        notify('Verifying and unpacking ALVR…', 96)
        contents = staging / 'contents'
        contents.mkdir()
        unpack(archive, contents)
        launcher = find_launcher(contents)
        launcher.chmod(launcher.stat().st_mode | 0o100)
        (contents / 'redline-install.json').write_text(json.dumps({'launcher': str(launcher.relative_to(contents)), 'version': release.get('tag_name', ''), 'sha256': hashed.hexdigest()}))
        contents.rename(destination)
    notify('ALVR launcher installed. Open it to finish the VR setup.', 100)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', required=True)
    args = parser.parse_args()
    try:
        install(args.destination)
    except Exception as error:
        notify(str(error))
        raise SystemExit(1)
