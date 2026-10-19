#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build a portable UI preview; privileged hardware services use native packages."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import urllib.request

PROJECT = Path(__file__).resolve().parents[1]


def fetch_tools(folder):
    folder.mkdir(parents=True, exist_ok=True)
    for asset in json.loads((PROJECT / 'packaging/appimage/tools.json').read_text()):
        path = folder / asset['name']
        expected = asset['sha256'].removeprefix('sha256:')
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            request = urllib.request.Request(asset['url'], headers={'User-Agent': 'Redline-build'})
            with urllib.request.urlopen(request, timeout=90) as response:
                data = response.read(asset['size'] + 1)
            if len(data) != asset['size'] or hashlib.sha256(data).hexdigest() != expected:
                raise RuntimeError('Pinned build tool changed: review and update tools.json')
            path.write_bytes(data)
        path.chmod(0o755)
        target = folder / path.stem
        if not (target / 'squashfs-root/AppRun').exists():
            target.mkdir(exist_ok=True)
            subprocess.run([str(path), '--appimage-extract'], cwd=target, check=True, stdout=subprocess.DEVNULL)
    qt = folder / 'linuxdeploy-plugin-qt-x86_64/squashfs-root/AppRun'
    wrapper = folder / 'linuxdeploy-plugin-qt'
    # A Python wrapper avoids shell interpolation of cache-directory paths.
    wrapper.write_text('#!/usr/bin/env python3\nimport os,sys\np='+repr(str(qt))+'\nos.execv(p,[p,*sys.argv[1:]])\n')
    wrapper.chmod(0o755)
    return folder / 'linuxdeploy-x86_64/squashfs-root/AppRun'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, default=PROJECT / 'runtime')
    parser.add_argument('--output', type=Path, default=PROJECT / 'dist')
    parser.add_argument('--tools', type=Path, default=Path.home() / '.cache/redline-build-tools')
    parser.add_argument('--version', default='0.9.0-alpha1')
    args = parser.parse_args()
    if platform.machine() != 'x86_64':
        parser.error('The first AppImage target is x86_64')
    if not (args.runtime / 'bin/redline-native').is_file():
        parser.error('Build the native application first')
    tools = args.tools.resolve()
    deploy = fetch_tools(tools)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='redline-appimage-') as temporary:
        appdir = Path(temporary) / 'Redline.AppDir'
        (appdir / 'usr/bin').mkdir(parents=True)
        shutil.copy2(args.runtime / 'bin/redline-native', appdir / 'usr/bin')
        shutil.copytree(args.runtime / 'lib', appdir / 'usr/lib', symlinks=True)
        (appdir / 'usr/libexec/redline').mkdir(parents=True)
        for name in ['redline-gpu-backend', 'redline-display.py', 'redline-capture.py', 'redline-vr-install.py']:
            source = args.runtime / 'libexec/redline' / name
            if source.exists():
                shutil.copy2(source, appdir / 'usr/libexec/redline' / name)
        # No D-Bus activation, Polkit rules or system services are included.
        desktop = Path(temporary) / 'redline.desktop'
        desktop.write_text('[Desktop Entry]\nName=Redline Preview\nComment=Portable development preview without hardware writes\nExec=redline-native\nIcon=redline\nType=Application\nCategories=System;Settings;\nTerminal=false\n')
        icon = Path(temporary) / 'redline.svg'
        shutil.copy2(PROJECT / 'resources/icon/app_256.svg', icon)
        docs = appdir / 'usr/share/doc/redline'
        docs.mkdir(parents=True)
        for name in ['COPYING', 'LICENSE', 'README.md']:
            shutil.copy2(PROJECT / name, docs / name)
        shutil.copy2(PROJECT / '3rdparty/redline-gpu/LICENSE', docs / 'LICENSE-LACT')
        # Preserve distribution copyright notices for bundled dependencies.
        for package in Path('/usr/share/doc').glob('*'):
            if package.name.startswith(('libqt6', 'qml6-', 'libbotan', 'libquazip', 'libspdlog', 'libpugixml')) and (package / 'copyright').exists():
                target = docs / 'third-party' / package.name
                target.mkdir(parents=True, exist_ok=True)
                shutil.copy2(package / 'copyright', target / 'copyright')
        qmake = os.environ.get('QMAKE', 'qmake6')
        plugin_root = Path(subprocess.check_output([qmake, '-query', 'QT_INSTALL_PLUGINS'], text=True).strip())
        platforms = [p.name for p in (plugin_root / 'platforms').glob('libqwayland*.so')]
        if (plugin_root / 'platforms/libqoffscreen.so').exists():
            platforms.append('libqoffscreen.so')
        env = dict(os.environ, EXTRA_PLATFORM_PLUGINS=';'.join(platforms), PATH=str(tools)+os.pathsep+os.environ['PATH'],
                   QML_SOURCES_PATHS=str(PROJECT / 'src/qml'), APPIMAGE_EXTRACT_AND_RUN='1',
                   LD_LIBRARY_PATH=str(appdir / 'usr/lib')+os.pathsep+os.environ.get('LD_LIBRARY_PATH',''),
                   VERSION=args.version, OUTPUT=f'Redline-Preview-{args.version}-x86_64.AppImage')
        subprocess.run([str(deploy), '--appdir', str(appdir), '--executable', str(appdir / 'usr/bin/redline-native'),
            '--desktop-file', str(desktop), '--icon-file', str(icon), '--plugin', 'qt',
            '--custom-apprun', str(PROJECT / 'packaging/appimage/AppRun'), '--output', 'appimage'],
            env=env, cwd=output, check=True)


if __name__ == '__main__':
    main()
