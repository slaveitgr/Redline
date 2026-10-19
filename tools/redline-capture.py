#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Explicit portal-selected local recording; never captures on startup."""
import argparse
import json
import os
from pathlib import Path
import signal
import sys
import uuid
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gio, GLib, Gst
Gst.init(None)

BUS = 'org.freedesktop.portal.Desktop'
PATH = '/org/freedesktop/portal/desktop'
IFACE = 'org.freedesktop.portal.ScreenCast'

def event(state, **data):
    print(json.dumps({'state': state, **data}), flush=True)

def make_pipeline(output, fps=30, audio=False, fd=None, node=None, synthetic=False, serial=None):
    pipeline = Gst.Pipeline.new('redline-recording')
    source = Gst.ElementFactory.make('videotestsrc' if synthetic else 'pipewiresrc', 'screen')
    if synthetic:
        source.set_property('num-buffers', 30)
    else:
        source.set_property('fd', fd)
        if serial is not None and source.find_property('target-object'):
            source.set_property('target-object', str(serial))
        else:
            source.set_property('path', str(node))
        source.set_property('do-timestamp', True)
    convert = Gst.ElementFactory.make('videoconvert')
    rate = Gst.ElementFactory.make('videorate')
    caps = Gst.ElementFactory.make('capsfilter')
    caps.set_property('caps', Gst.Caps.from_string(f'video/x-raw,framerate={fps}/1'))
    encoder = Gst.ElementFactory.make('vp8enc')
    encoder.set_property('deadline', 1)
    encoder.set_property('cpu-used', 8)
    encoder.set_property('target-bitrate', 8_000_000)
    queue = Gst.ElementFactory.make('queue')
    mux = Gst.ElementFactory.make('webmmux', 'mux')
    sink = Gst.ElementFactory.make('filesink')
    sink.set_property('location', str(output))
    sink.set_property('sync', False)
    elements = [source, convert, rate, caps, encoder, queue, mux, sink]
    if any(item is None for item in elements):
        raise RuntimeError('Required GStreamer recording plugins are missing.')
    for item in elements:
        pipeline.add(item)
    for left, right in zip(elements, elements[1:]):
        if not left.link(right):
            raise RuntimeError('Could not link the recording pipeline.')
    if audio:
        sound = Gst.ElementFactory.make('audiotestsrc' if synthetic else 'pulsesrc')
        if synthetic:
            sound.set_property('num-buffers', 45)
        else:
            sound.set_property('device', '@DEFAULT_MONITOR@')
        chain = [sound, Gst.ElementFactory.make('audioconvert'), Gst.ElementFactory.make('audioresample'), Gst.ElementFactory.make('vorbisenc'), Gst.ElementFactory.make('queue')]
        if any(item is None for item in chain):
            raise RuntimeError('Required system-audio plugins are missing.')
        for item in chain:
            pipeline.add(item)
        for left, right in zip(chain, chain[1:] + [mux]):
            if not left.link(right):
                raise RuntimeError('Could not link system audio.')
    return pipeline

class Recorder:
    def __init__(self, args):
        self.args = args
        self.loop = GLib.MainLoop()
        self.pipeline = None
        self.connection = None
        self.session = None
        self.fd = None
        self.request_path = None
        self.stopping = False
        self.failed = False
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self.stop)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self.stop)
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, self.command)

    def command(self, stream, condition):
        if condition & GLib.IO_HUP or stream.readline().strip() == 'stop':
            self.stop()
            return False
        return True

    def request(self, method, signature, leading, options, callback):
        token = 'redline_' + uuid.uuid4().hex
        options['handle_token'] = GLib.Variant('s', token)
        sender = self.connection.get_unique_name().lstrip(':').replace('.', '_')
        self.request_path = f'{PATH}/request/{sender}/{token}'
        def response(connection, sender, path, interface, name, parameters, unused):
            connection.signal_unsubscribe(subscription)
            self.request_path = None
            code, results = parameters.unpack()
            if code:
                self.error('Screen selection was cancelled or denied.')
                return
            try:
                callback(results)
            except Exception as error:
                self.error(str(error))
        subscription = self.connection.signal_subscribe(BUS, 'org.freedesktop.portal.Request', 'Response', self.request_path, None, Gio.DBusSignalFlags.NONE, response, None)
        self.connection.call_sync(BUS, PATH, IFACE, method, GLib.Variant(signature, (*leading, options)), GLib.VariantType.new('(o)'), Gio.DBusCallFlags.NONE, 10000, None)

    def created(self, result):
        self.session = result['session_handle']
        self.connection.signal_subscribe(BUS, 'org.freedesktop.portal.Session', 'Closed', self.session, None, Gio.DBusSignalFlags.NONE, lambda *unused: self.stop(), None)
        options = {'types': GLib.Variant('u', 3), 'multiple': GLib.Variant('b', False)}
        try:
            modes = self.connection.call_sync(BUS, PATH, 'org.freedesktop.DBus.Properties', 'Get', GLib.Variant('(ss)', (IFACE, 'AvailableCursorModes')), None, Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]
            if modes & 2:
                options['cursor_mode'] = GLib.Variant('u', 2)
        except GLib.Error:
            pass
        self.request('SelectSources', '(oa{sv})', (self.session,), options, self.selected)

    def selected(self, unused):
        self.request('Start', '(osa{sv})', (self.session, ''), {}, self.started)

    def started(self, result):
        streams = result.get('streams', [])
        if len(streams) != 1:
            raise RuntimeError('No single capture stream was selected.')
        handle, descriptors = self.connection.call_with_unix_fd_list_sync(BUS, PATH, IFACE, 'OpenPipeWireRemote', GLib.Variant('(oa{sv})', (self.session, {})), GLib.VariantType.new('(h)'), Gio.DBusCallFlags.NONE, 10000, None, None)
        self.fd = descriptors.get(handle.unpack()[0])
        # Prefer portal v6 stream serials; use legacy node IDs on older portals.
        self.pipeline = make_pipeline(self.args.output, self.args.fps, self.args.audio, self.fd, streams[0][0], serial=streams[0][1].get('pipewire-serial'))
        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect('message', self.bus_message)
        if self.pipeline.set_state(Gst.State.PLAYING) == Gst.StateChangeReturn.FAILURE:
            raise RuntimeError('Could not start the recording pipeline.')

    def bus_message(self, bus, message):
        if message.type == Gst.MessageType.ERROR:
            error, debug = message.parse_error()
            self.error(error.message)
        elif message.type == Gst.MessageType.STATE_CHANGED and message.src == self.pipeline:
            old, new, pending = message.parse_state_changed()
            if new == Gst.State.PLAYING:
                event('recording', output=self.args.output)
        elif message.type == Gst.MessageType.EOS:
            event('saved', output=self.args.output)
            self.loop.quit()

    def error(self, message):
        if not self.failed:
            event('error', message=message)
        self.failed = True
        self.loop.quit()

    def stop(self):
        if self.stopping:
            return False
        self.stopping = True
        if self.pipeline:
            event('stopping')
            self.pipeline.send_event(Gst.Event.new_eos())
            GLib.timeout_add_seconds(10, self.stop_timeout)
        else:
            if self.request_path and self.connection:
                try:
                    self.connection.call_sync(BUS, self.request_path, 'org.freedesktop.portal.Request', 'Close', None, None, Gio.DBusCallFlags.NONE, 2000, None)
                except GLib.Error:
                    pass
            self.loop.quit()
        return False

    def stop_timeout(self):
        self.error('Recording finalization timed out. The file may be incomplete.')
        return False

    def run(self):
        try:
            self.connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            event('selecting')
            self.request('CreateSession', '(a{sv})', (), {'session_handle_token': GLib.Variant('s', 'redline_' + uuid.uuid4().hex)}, self.created)
            self.loop.run()
        except Exception as error:
            self.error(str(error))
        finally:
            if self.pipeline:
                self.pipeline.set_state(Gst.State.NULL)
            if self.session and self.connection:
                try:
                    self.connection.call_sync(BUS, self.session, 'org.freedesktop.portal.Session', 'Close', None, None, Gio.DBusCallFlags.NONE, 2000, None)
                except GLib.Error:
                    pass
            if self.fd is not None:
                os.close(self.fd)
        return 1 if self.failed else 0

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output')
    parser.add_argument('--fps', type=int, choices=[30, 60], default=30)
    parser.add_argument('--audio', action='store_true')
    args = parser.parse_args()
    if args.check:
        required = ['pipewiresrc', 'videoconvert', 'videorate', 'vp8enc', 'webmmux', 'filesink']
        missing = [name for name in required if not Gst.ElementFactory.find(name)]
        event('capabilities', supported=not missing, missing=missing, audio=all(Gst.ElementFactory.find(n) for n in ['pulsesrc', 'vorbisenc', 'audioresample']))
        raise SystemExit(bool(missing))
    if not args.output or not Path(args.output).is_absolute() or Path(args.output).exists():
        parser.error('A new absolute output path is required.')
    raise SystemExit(Recorder(args).run())
