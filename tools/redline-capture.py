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

CODECS = {
    'vp8': dict(label='VP8 / WebM', extension='webm', video='vp8enc', audio='vorbisenc', mux='webmmux'),
    'vp9': dict(label='VP9 / WebM', extension='webm', video='vp9enc', audio='vorbisenc', mux='webmmux'),
    'h264': dict(label='H.264 / MP4', extension='mp4', video='x264enc', audio='avenc_aac', mux='mp4mux'),
}
RESOLUTIONS = {'native': None, '720p': (1280, 720), '1080p': (1920, 1080)}


def available_codecs():
    result = []
    for key, profile in CODECS.items():
        required = [profile['video'], profile['audio'], profile['mux']]
        if key == 'h264':
            required.append('h264parse')
        if all(Gst.ElementFactory.find(name) for name in required):
            result.append(dict(id=key, label=profile['label'], extension=profile['extension']))
    return result


def make_pipeline(output, fps=30, audio=False, fd=None, node=None, synthetic=False, serial=None,
                  codec='vp8', bitrate=8, resolution='native', microphone=False):
    if codec not in CODECS or resolution not in RESOLUTIONS or fps not in (30, 60) or not 2 <= bitrate <= 100:
        raise ValueError('Unsupported recording configuration.')
    profile = CODECS[codec]
    pipeline = Gst.Pipeline.new('redline-recording')
    def element(name, instance=None):
        item = Gst.ElementFactory.make(name, instance)
        if item is None:
            raise RuntimeError('Missing GStreamer plugin: ' + name)
        pipeline.add(item)
        return item
    def link(chain):
        for left, right in zip(chain, chain[1:]):
            if not left.link(right):
                raise RuntimeError('Could not connect recording elements.')
    source = element('videotestsrc' if synthetic else 'pipewiresrc', 'screen')
    if synthetic:
        source.set_property('num-buffers', 30)
    else:
        source.set_property('fd', fd)
        if serial is not None and source.find_property('target-object'):
            source.set_property('target-object', str(serial))
        else:
            source.set_property('path', str(node))
        source.set_property('do-timestamp', True)
    convert, scale, rate = element('videoconvert'), element('videoscale'), element('videorate')
    scale.set_property('add-borders', True)
    caps = element('capsfilter')
    dimensions = RESOLUTIONS[resolution]
    spec = f'video/x-raw,framerate={fps}/1,pixel-aspect-ratio=1/1'
    if dimensions:
        spec += f',width={dimensions[0]},height={dimensions[1]}'
    caps.set_property('caps', Gst.Caps.from_string(spec))
    encoder = element(profile['video'], 'video-encoder')
    if codec in ('vp8', 'vp9'):
        encoder.set_property('deadline', 1)
        encoder.set_property('cpu-used', 8)
        encoder.set_property('target-bitrate', bitrate * 1_000_000)
    else:
        encoder.set_property('bitrate', bitrate * 1000)
        Gst.util_set_object_arg(encoder, 'speed-preset', 'ultrafast')
        Gst.util_set_object_arg(encoder, 'tune', 'zerolatency')
    video = [source, convert, scale, rate, caps, encoder]
    if codec == 'h264':
        video.append(element('h264parse'))
    queue, mux, sink = element('queue'), element(profile['mux'], 'mux'), element('filesink')
    if codec == 'h264':
        mux.set_property('faststart', True)
    sink.set_property('location', str(output))
    sink.set_property('sync', False)
    link(video + [queue, mux, sink])
    inputs = ([True] if audio else []) + ([False] if microphone else [])
    if inputs:
        mixer = element('audiomixer', 'audio-mixer')
        for index, system in enumerate(inputs):
            sound = element('audiotestsrc' if synthetic else 'pulsesrc', 'system-audio' if system else 'microphone')
            if synthetic:
                sound.set_property('num-buffers', 45)
                sound.set_property('freq', 440.0 if system else 880.0)
            elif system:
                sound.set_property('device', '@DEFAULT_MONITOR@')
            volume = element('volume')
            volume.set_property('volume', 0.5 if len(inputs) == 2 else 1.0)
            audio_caps = element('capsfilter')
            audio_caps.set_property('caps', Gst.Caps.from_string('audio/x-raw,rate=48000,channels=2'))
            link([sound, element('audioconvert'), element('audioresample'), audio_caps, volume, element('queue'), mixer])
        audio_encoder = element(profile['audio'])
        if codec == 'h264':
            audio_encoder.set_property('bitrate', 128000)
        link([mixer, element('audioconvert'), audio_encoder, element('queue'), mux])
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
        self.pipeline = make_pipeline(self.args.output, self.args.fps, self.args.audio, self.fd, streams[0][0], serial=streams[0][1].get('pipewire-serial'), codec=self.args.codec, bitrate=self.args.bitrate, resolution=self.args.resolution, microphone=self.args.microphone)
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
    parser.add_argument('--microphone', action='store_true')
    parser.add_argument('--codec', choices=list(CODECS), default='vp8')
    parser.add_argument('--bitrate', type=int, choices=range(2,101), default=8)
    parser.add_argument('--resolution', choices=list(RESOLUTIONS), default='native')
    args = parser.parse_args()
    if args.check:
        required = ['pipewiresrc', 'videoconvert', 'videoscale', 'videorate', 'filesink']
        missing = [name for name in required if not Gst.ElementFactory.find(name)]
        codecs = available_codecs()
        event('capabilities', supported=not missing and bool(codecs), codecs=codecs, missing=missing, audio=all(Gst.ElementFactory.find(n) for n in ['pulsesrc', 'audiomixer', 'audioconvert', 'audioresample', 'volume']))
        raise SystemExit(bool(missing) or not codecs)
    if os.getenv('REDLINE_READ_ONLY') is not None:
        parser.error('Recording is disabled in UI preview.')
    if not args.output or not Path(args.output).is_absolute() or Path(args.output).exists():
        parser.error('A new absolute output path is required.')
    raise SystemExit(Recorder(args).run())
