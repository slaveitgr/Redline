#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Interactive portal screenshot; never runs on application startup."""
import json
import os
from pathlib import Path
import signal
import sys
import uuid
from gi.repository import Gio, GLib


def save_image(uri):
    file = Gio.File.new_for_uri(uri)
    source = file.get_path()
    if not source:
        raise ValueError('The screenshot portal did not return a local image.')
    source = Path(source)
    if source.is_symlink() or not source.is_file() or source.stat().st_size > 100*1024*1024:
        raise ValueError('Invalid screenshot result.')
    with source.open('rb') as stream:
        data = stream.read(100*1024*1024+1)
    if len(data)>100*1024*1024:
        raise ValueError('Screenshot result is too large.')
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('The screenshot result is not a PNG image.')
    folder = Path(GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES) or str(Path.home()/'Pictures')) / 'Redline'
    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    output = folder / ('Redline-' + uuid.uuid4().hex + '.png')
    with output.open('xb') as stream:
        os.chmod(output, 0o600)
        stream.write(data)
    return str(output)


def main():
    if os.getenv('REDLINE_READ_ONLY') is not None:
        raise ValueError('Screenshots are disabled in UI preview.')
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    loop = GLib.MainLoop()
    token = 'redline_' + uuid.uuid4().hex
    sender = connection.get_unique_name().lstrip(':').replace('.', '_')
    path = '/org/freedesktop/portal/desktop/request/' + sender + '/' + token
    result = dict(error='Screenshot cancelled.')
    def response(bus, sender, path, interface, name, parameters, unused):
        code, values = parameters.unpack()
        if code == 0:
            try:
                result.clear()
                result['saved'] = save_image(values['uri'])
            except Exception as error:
                result['error'] = str(error)
        loop.quit()
    subscription = connection.signal_subscribe('org.freedesktop.portal.Desktop', 'org.freedesktop.portal.Request', 'Response', path, None, Gio.DBusSignalFlags.NONE, response, None)
    def cancel():
        try:
            connection.call_sync('org.freedesktop.portal.Desktop', path, 'org.freedesktop.portal.Request', 'Close', None, None, 0, 2000, None)
        except GLib.Error:
            pass
        loop.quit()
        return False
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, cancel)
    GLib.timeout_add_seconds(180, cancel)
    try:
        connection.call_sync('org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop', 'org.freedesktop.portal.Screenshot', 'Screenshot',
            GLib.Variant('(sa{sv})', ('', {'handle_token':GLib.Variant('s', token),'interactive':GLib.Variant('b', True)})), None, 0, 10000, None)
        loop.run()
    finally:
        connection.signal_unsubscribe(subscription)
    print(json.dumps(result), flush=True)
    return 0 if 'saved' in result else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print(json.dumps(dict(error=str(error)[:500])), flush=True)
        sys.exit(1)
