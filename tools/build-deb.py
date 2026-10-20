#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Stage an Ubuntu 26.10 amd64 development package, without installing it."""
import argparse
import gzip
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, default=PROJECT / 'runtime')
    parser.add_argument('--output', type=Path, default=PROJECT / 'dist')
    parser.add_argument('--version', default='0.9.0~alpha1')
    parser.add_argument('--target', default='Ubuntu 26.10 amd64')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9 .()-]+', args.target):
        parser.error('Invalid target label')
    subprocess.run(['dpkg', '--validate-version', args.version], check=True)
    runtime = args.runtime.resolve()
    for path in ['bin/redline-native', 'lib/libredline-core.so', 'libexec/redline/redline-gpu-backend']:
        if not (runtime / path).is_file():
            parser.error('Build the native app and GPU engine first: missing ' + path)
    if subprocess.check_output(['dpkg', '--print-architecture'], text=True).strip() != 'amd64':
        parser.error('This package target currently supports amd64 only')
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='redline-deb-') as temporary:
        build = Path(temporary)
        stage = build / 'root'
        shutil.copytree(runtime, stage / 'usr', symlinks=True)
        private = stage / 'usr/lib/redline'
        private.mkdir(parents=True)
        shutil.move(stage / 'usr/lib/libredline-core.so', private / 'libredline-core.so')
        for script in (PROJECT / 'packaging/bin').iterdir():
            target = stage / ('usr/bin' if script.name in ['redline', 'redline-preview'] else 'usr/libexec/redline') / script.name
            shutil.copy2(script, target)
            target.chmod(0o755)
        units = stage / 'usr/lib/systemd/system'
        units.mkdir(parents=True, exist_ok=True)
        for file in (PROJECT / 'packaging/systemd').iterdir():
            shutil.copy2(file, units / file.name)
        rules = stage / 'usr/share/polkit-1/rules.d'
        rules.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / 'packaging/49-redline-hardware.rules', rules / '49-redline-hardware.rules')
        policy = stage / 'usr/share/polkit-1/actions'
        for file in (PROJECT / 'packaging/polkit').iterdir():
            shutil.copy2(file, policy / file.name)
        services = stage / 'usr/share/dbus-1/system-services'
        for file in services.glob('*.service'):
            text = file.read_text().replace(str(runtime), '/usr')
            unit = 'redline-cpu-killer.service' if 'helperkiller' in file.name else 'redline-cpu.service'
            text += '\nSystemdService=' + unit + '\n'
            text = text.replace('Exec=/usr/libexec/', 'Exec=/usr/bin/env LD_LIBRARY_PATH=/usr/lib/redline /usr/libexec/')
            file.write_text(text)
        desktop = stage / 'usr/share/applications/io.github.redline.native.Redline.desktop'
        desktop.write_text(desktop.read_text().replace('Exec=redline-native', 'Exec=redline'))
        preview = desktop.with_name('io.github.redline.native.Preview.desktop')
        preview.write_text('[Desktop Entry]\nName=Redline Preview (read-only)\nNoDisplay=true\nComment=Review Redline without hardware writes, installs or recording\nExec=redline-preview\nIcon=redline\nType=Application\nTerminal=false\nCategories=System;Settings;\n')
        docs = stage / 'usr/share/doc/redline-graphics'
        docs.mkdir(parents=True)
        shutil.copy2(PROJECT / 'COPYING', docs / 'COPYING')
        (docs / 'copyright').write_text('Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/\nUpstream-Name: Redline\nSource: https://github.com/slaveitgr/Redline\n\nFiles: *\nCopyright: Slave IT Solutions and CoreCtrl contributors; see preserved source notices\nLicense: GPL-3+\n See COPYING for the complete license.\n\nFiles: 3rdparty/redline-gpu/*\nCopyright: LACT contributors; see preserved source notices\nLicense: MIT\n See LICENSE-LACT for the complete license.\n')
        shutil.copy2(PROJECT / '3rdparty/redline-gpu/LICENSE', docs / 'LICENSE-LACT')
        with gzip.open(docs / 'changelog.Debian.gz', 'wt') as changelog:
            changelog.write(f'redline-graphics ({args.version}) stonking; urgency=low\n\n  * Development preview for {args.target}; see README for capability limits.\n\n -- Slave IT Solutions <info@slave.gr>  Tue, 20 Oct 2026 12:00:00 +0300\n')
        (build / 'debian').mkdir()
        (build / 'debian/control').write_text('Source: redline-graphics\nSection: utils\nPriority: optional\nMaintainer: Slave IT Solutions <info@slave.gr>\n\nPackage: redline-graphics\nArchitecture: amd64\nDescription: Redline development preview\n')
        binaries = [stage / 'usr/bin/redline-native', private / 'libredline-core.so'] + list((stage / 'usr/libexec/redline').glob('redline_*')) + [stage / 'usr/libexec/redline/redline-gpu-backend']
        command = ['dpkg-shlibdeps', '--ignore-missing-info', '-O', '-l' + str(private)] + ['-e' + str(path) for path in binaries if path.is_file()]
        dependencies = subprocess.check_output(command, cwd=build, text=True).strip().split('shlibs:Depends=', 1)[1]
        extra = ['python3 (>= 3.12)', 'python3-gi', 'gir1.2-gstreamer-1.0', 'gstreamer1.0-pipewire', 'gstreamer1.0-plugins-base', 'gstreamer1.0-plugins-good', 'gstreamer1.0-pulseaudio', 'xdg-desktop-portal', 'dbus-user-session', 'pkexec', 'adduser', 'passwd', 'psmisc', 'init-system-helpers', 'qt6-qpa-plugins', 'qt6-wayland', 'libqt6svg6', 'qml6-module-qtquick', 'qml6-module-qtquick-controls', 'qml6-module-qtquick-layouts', 'qml6-module-qtquick-templates', 'qml6-module-qtquick-window', 'qml6-module-qtqml', 'qml6-module-qtqml-models', 'qml6-module-qtqml-workerscript', 'qml6-module-qtcharts', 'qml6-module-qt-labs-platform']
        plugin_root = Path(subprocess.check_output(['qmake6', '-query', 'QT_INSTALL_PLUGINS'], text=True).strip())
        svg_plugin = plugin_root / 'imageformats/libqsvg.so'
        if not svg_plugin.is_file():
            parser.error('Install the Qt SVG image plugin before packaging')
        owner = subprocess.check_output(['dpkg-query', '-S', str(svg_plugin)], text=True).split(': ', 1)[0].split(':', 1)[0]
        if owner not in extra:
            extra.append(owner)
        metadata = stage / 'DEBIAN'
        metadata.mkdir()
        size = sum(p.stat().st_size for p in stage.rglob('*') if p.is_file()) // 1024
        (metadata / 'control').write_text(f'Package: redline-graphics\nVersion: {args.version}\nArchitecture: amd64\nMaintainer: Slave IT Solutions <info@slave.gr>\nSection: utils\nPriority: optional\nInstalled-Size: {size}\nDepends: {dependencies}, '+', '.join(extra)+f'\nRecommends: ffmpeg, mangohud, gamemode, gamescope, gstreamer1.0-plugins-ugly, gstreamer1.0-plugins-bad, gstreamer1.0-libav\nSuggests: flatpak, xdg-desktop-portal-gnome\nHomepage: https://github.com/slaveitgr/Redline\nDescription: Native Linux graphics and gaming dashboard (development preview)\n Adrenalin-inspired Qt interface with integrated CoreCtrl/LACT-derived controls,\n monitoring, overlay launch integration and experimental portal recording.\n Built for {args.target}; full Windows feature parity is not implemented.\n')
        for name in ['postinst', 'prerm', 'postrm']:
            shutil.copy2(PROJECT / 'packaging/debian' / name, metadata / name)
            (metadata / name).chmod(0o755)
        output = args.output.resolve() / f'redline-graphics_{args.version}_amd64.deb'
        subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(stage), str(output)], check=True)
        print(json.dumps({'package': str(output), 'target': args.target, 'version': args.version}))

if __name__ == '__main__':
    main()
