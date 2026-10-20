#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Explicit portal-selected local recording; never captures on startup."""
import argparse
import base64
import json
import os
from pathlib import Path
import signal
import sys
import uuid
import tempfile
import shutil
import subprocess
import threading
from collections import deque
from urllib.parse import urlsplit, quote
import gi
gi.require_version('Gst', '1.0')
from gi.repository import Gio, GLib, Gst
Gst.init(None)

BUS = 'org.freedesktop.portal.Desktop'
PATH = '/org/freedesktop/portal/desktop'
IFACE = 'org.freedesktop.portal.ScreenCast'

EVENT_LOCK = threading.Lock()

def event(state, **data):
    with EVENT_LOCK:
        sys.stdout.write(json.dumps({'state': state, **data}) + '\n')
        sys.stdout.flush()

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


def stream_location(server, key):
    if not isinstance(server, str) or not isinstance(key, str) or len(server) > 2048 or not 1 <= len(key) <= 1024:
        raise ValueError('Enter a server URL and stream key.')
    if any(ord(c) < 33 or ord(c) == 127 for c in server + key):
        raise ValueError('Server and key must not contain spaces or control characters.')
    try:
        parsed = urlsplit(server)
        valid = parsed.scheme in ('rtmp', 'rtmps') and parsed.hostname and parsed.port != 0 and not parsed.username and not parsed.password and not parsed.query and not parsed.fragment and parsed.path.strip('/')
    except ValueError:
        valid = False
    if not valid:
        raise ValueError('Use an RTMP or RTMPS server URL with an application path and a separate key.')
    return server.rstrip('/') + '/' + quote(key, safe='-_.~')


def streaming_supported():
    return all(Gst.ElementFactory.find(n) for n in ('x264enc','h264parse','avenc_aac','aacparse','flvmux','rtmp2sink'))


def make_pipeline(output, fps=30, audio=False, fd=None, node=None, synthetic=False, serial=None,
                  codec='vp8', bitrate=8, resolution='native', microphone=False, replay=False, stream=None, audio_bitrate=128, archive=False, preview=False, on_preview=None):
    if codec not in CODECS or resolution not in RESOLUTIONS or fps not in (30, 60) or not 2 <= bitrate <= 100:
        raise ValueError('Unsupported recording configuration.')
    if archive and (not stream or not output):
        raise ValueError('Archiving requires a stream and an output file.')
    if stream and (codec != 'h264' or replay or audio_bitrate not in (96,128,160,192,256,320)):
        raise ValueError('Unsupported streaming configuration.')
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
    video_source = source
    if preview:
        video_source = element('tee', 'preview-fork')
        link([source, video_source])
        branch = element('queue', 'preview-queue')
        branch.set_property('leaky', 2)
        branch.set_property('max-size-buffers', 1)
        preview_scale = element('videoscale')
        preview_scale.set_property('add-borders', True)
        preview_rate = element('videorate')
        preview_rate.set_property('drop-only', True)
        preview_caps = element('capsfilter')
        preview_caps.set_property('caps', Gst.Caps.from_string('video/x-raw,width=640,height=360,framerate=5/1,pixel-aspect-ratio=1/1'))
        jpeg = element('jpegenc')
        jpeg.set_property('quality', 60)
        sink = element('appsink', 'preview')
        sink.set_property('emit-signals', True)
        sink.set_property('max-buffers', 1)
        sink.set_property('drop', True)
        sink.set_property('sync', False)
        def frame(sink):
            sample = sink.emit('pull-sample')
            if sample is None:
                return Gst.FlowReturn.OK
            buffer = sample.get_buffer()
            if buffer.get_size() <= 200000:
                data = buffer.extract_dup(0, buffer.get_size())
                if on_preview:
                    on_preview(data)
                else:
                    event('preview', jpeg=base64.b64encode(data).decode('ascii'))
            return Gst.FlowReturn.OK
        sink.connect('new-sample', frame)
        link([video_source, branch, element('videoconvert'), preview_scale, preview_rate, preview_caps, jpeg, sink])
    video = [video_source] + ([element('queue')] if preview else []) + [convert, scale, rate, caps, encoder]
    if codec == 'h264':
        video.append(element('h264parse'))
    if stream:
        encoder.set_property('key-int-max', fps * 2)
        mux = element('flvmux', 'mux')
        mux.set_property('streamable', True)
        sink = element('rtmp2sink', 'stream-sink')
        sink.set_property('location', stream)
        if archive:
            archive_mux = element('mp4mux', 'archive-mux')
            archive_mux.set_property('faststart', True)
            archive_sink = element('filesink', 'archive-file')
            archive_sink.set_property('location', str(output))
            archive_sink.set_property('sync', False)
            fork = element('tee', 'encoded-video')
            link(video + [fork])
            link([fork, element('queue'), mux, sink])
            link([fork, element('queue'), archive_mux, archive_sink])
        else:
            link(video + [element('queue'), mux, sink])
    elif replay:
        if codec != 'vp8':
            raise ValueError('Replay requires VP8 / WebM.')
        encoder.set_property('keyframe-max-dist', fps * 2)
        mux = element('splitmuxsink', 'replay-sink')
        mux.set_property('location', str(output))
        mux.set_property('max-size-time', 2 * Gst.SECOND)
        mux.set_property('max-size-bytes', 16 * 1024 * 1024)
        mux.set_property('muxer-factory', 'webmmux')
        mux.set_property('async-finalize', True)
        link(video + [element('queue'), mux])
    else:
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
            chain = [sound, element('audioconvert'), element('audioresample'), audio_caps]
            if preview:
                level = element('level', 'system-level' if system else 'microphone-level')
                level.set_property('interval', Gst.SECOND // 5)
                chain.append(level)
            link(chain + [volume, element('queue'), mixer])
        audio_encoder = element(profile['audio'])
        if codec == 'h264':
            audio_encoder.set_property('bitrate', audio_bitrate * 1000)
        audio_chain = [mixer, element('audioconvert'), audio_encoder]
        if stream:
            audio_chain.append(element('aacparse'))
        audio_chain.append(element('queue'))
        link(audio_chain)
        if replay:
            pad = mux.request_pad_simple('audio_%u')
            if audio_chain[-1].get_static_pad('src').link(pad) != Gst.PadLinkReturn.OK:
                raise RuntimeError('Could not connect replay audio.')
        elif archive:
            fork = element('tee', 'encoded-audio')
            link([audio_chain[-1], fork])
            link([fork, element('queue'), mux])
            link([fork, element('queue'), archive_mux])
        else:
            link([audio_chain[-1], mux])
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
        self.replay_dir = tempfile.TemporaryDirectory(prefix='redline-replay-') if args.replay_seconds else None
        self.fragments = deque()
        self.export_thread = None
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self.stop)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self.stop)
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, self.command)

    def command(self, stream, condition):
        command = '' if condition & GLib.IO_HUP else stream.readline().strip()
        if command == 'save-replay' and self.replay_dir and not self.stopping:
            self.save_replay()
            return True
        if condition & GLib.IO_HUP or command == 'stop':
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
                self.error('Stream setup failed.' if getattr(self.args,'stream',False) else str(error))
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
        self.pipeline = make_pipeline(str(Path(self.replay_dir.name) / "chunk-%06d.webm") if self.replay_dir else self.args.output, self.args.fps, self.args.audio, self.fd, streams[0][0], serial=streams[0][1].get('pipewire-serial'), codec=self.args.codec, bitrate=self.args.bitrate, resolution=self.args.resolution, microphone=self.args.microphone, replay=bool(self.replay_dir), stream=getattr(self.args,"stream_location",None), audio_bitrate=getattr(self.args,"audio_bitrate",128), archive=getattr(self.args,"archive",False), preview=getattr(self.args,"preview",False))
        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect('message', self.bus_message)
        if self.pipeline.set_state(Gst.State.PLAYING) == Gst.StateChangeReturn.FAILURE:
            raise RuntimeError('Could not start the recording pipeline.')

    def bus_message(self, bus, message):
        if message.type == Gst.MessageType.ELEMENT:
            structure = message.get_structure()
            if structure and structure.get_name() == 'level':
                peaks = structure.get_value('peak')
                peak = max(peaks) if peaks else -60
                event('audio-level', source=message.src.get_name(), value=max(0.0, min(1.0, (peak + 60) / 60)))
                return
        if message.type == Gst.MessageType.ELEMENT and self.replay_dir:
            structure = message.get_structure()
            if structure and structure.get_name() == 'splitmuxsink-fragment-closed':
                self.fragments.append(Path(structure.get_value('location')))
                while len(self.fragments) > self.args.replay_seconds // 2:
                    self.fragments.popleft().unlink(missing_ok=True)
                event('replay-ready', buffered=len(self.fragments) * 2)
        if message.type == Gst.MessageType.ERROR:
            error, debug = message.parse_error()
            if not getattr(self.args, 'stream', False):
                print(f"GStreamer {message.src.get_name()}: {error.message}; {debug}", file=sys.stderr, flush=True)
            self.error('Stream connection or encoding failed. Check the server, key and network.' if getattr(self.args, 'stream', False) else error.message)
        elif message.type == Gst.MessageType.STATE_CHANGED and message.src == self.pipeline:
            old, new, pending = message.parse_state_changed()
            if new == Gst.State.PLAYING:
                event('streaming' if getattr(self.args,'stream',False) else 'recording', output=self.args.output)
        elif message.type == Gst.MessageType.EOS:
            event('stream-stopped' if getattr(self.args,'stream',False) else 'buffer-stopped' if self.replay_dir else 'saved', output=self.args.output, archived=bool(getattr(self.args,'archive',False)))
            self.loop.quit()

    def save_replay(self):
        if self.export_thread and self.export_thread.is_alive():
            event('replay-notice', message='Replay export is already in progress.')
            return
        if not self.fragments:
            event('replay-notice', message='Wait for at least one completed replay segment.')
            return
        snapshot = tempfile.TemporaryDirectory(prefix='redline-replay-export-')
        files = []
        try:
            for index, source in enumerate(self.fragments):
                target = Path(snapshot.name) / f'{index:06d}.webm'
                os.link(source, target)
                files.append(target)
        except OSError:
            snapshot.cleanup()
            event('replay-notice', message='Could not snapshot replay segments.')
            return
        target = Path(self.args.output).with_name('Replay-' + uuid.uuid4().hex + '.webm')
        event('replay-exporting')
        def export():
            try:
                playlist = Path(snapshot.name) / 'segments.txt'
                playlist.write_text(''.join("file '" + str(f) + "'\n" for f in files))
                result = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', str(playlist), '-c', 'copy', '-t', str(self.args.replay_seconds), '-n', str(target)], capture_output=True, timeout=90)
                if result.returncode:
                    target.unlink(missing_ok=True)
                    event('replay-notice', message='Replay export failed.')
                else:
                    event('replay-saved', output=str(target))
            except Exception:
                target.unlink(missing_ok=True)
                event('replay-notice', message='Replay export failed or timed out.')
            finally:
                snapshot.cleanup()
        self.export_thread = threading.Thread(target=export)
        self.export_thread.start()

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
        self.error('Stream shutdown timed out.' if getattr(self.args,'stream',False) else 'Recording finalization timed out. The file may be incomplete.')
        return False

    def run(self):
        try:
            self.connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            event('selecting')
            self.request('CreateSession', '(a{sv})', (), {'session_handle_token': GLib.Variant('s', 'redline_' + uuid.uuid4().hex)}, self.created)
            self.loop.run()
        except Exception as error:
            self.error('Stream setup failed.' if getattr(self.args,'stream',False) else str(error))
        finally:
            if self.pipeline:
                self.pipeline.set_state(Gst.State.NULL)
            if self.session and self.connection:
                try:
                    self.connection.call_sync(BUS, self.session, 'org.freedesktop.portal.Session', 'Close', None, None, Gio.DBusCallFlags.NONE, 2000, None)
                except GLib.Error:
                    pass
            if self.export_thread:
                self.export_thread.join()
            if self.replay_dir:
                self.replay_dir.cleanup()
            if self.fd is not None:
                os.close(self.fd)
        return 1 if self.failed else 0

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--stream', action='store_true')
    parser.add_argument('--archive', action='store_true')
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--output')
    parser.add_argument('--fps', type=int, choices=[30, 60], default=30)
    parser.add_argument('--audio', action='store_true')
    parser.add_argument('--replay-seconds', type=int, choices=[15,30,60,120], default=0)
    parser.add_argument('--microphone', action='store_true')
    parser.add_argument('--codec', choices=list(CODECS), default='vp8')
    parser.add_argument('--bitrate', type=int, choices=range(2,101), default=8)
    parser.add_argument('--resolution', choices=list(RESOLUTIONS), default='native')
    args = parser.parse_args()
    os.umask(0o077)
    if args.check:
        required = ['pipewiresrc', 'videoconvert', 'videoscale', 'videorate', 'filesink']
        missing = [name for name in required if not Gst.ElementFactory.find(name)]
        codecs = available_codecs()
        event('capabilities', preview=all(Gst.ElementFactory.find(n) for n in ('tee','queue','jpegenc','appsink','level')), streaming=streaming_supported(), supported=not missing and bool(codecs), codecs=codecs, missing=missing, replay=bool(shutil.which('ffmpeg') and Gst.ElementFactory.find('splitmuxsink')), audio=all(Gst.ElementFactory.find(n) for n in ['pulsesrc', 'audiomixer', 'audioconvert', 'audioresample', 'volume']))
        raise SystemExit(bool(missing) or not codecs)
    if os.getenv('REDLINE_READ_ONLY') is not None:
        parser.error('Recording is disabled in UI preview.')
    if args.stream:
        try:
            config = json.loads(sys.stdin.readline(8193))
            args.stream_location = stream_location(config.get('server'), config.get('key'))
            args.audio_bitrate = int(config.get('audioBitrate',128))
            if args.archive and (not args.output or not Path(args.output).is_absolute() or Path(args.output).exists()):
                raise ValueError()
            if args.codec != 'h264' or args.replay_seconds or args.audio_bitrate not in (96,128,160,192,256,320):
                raise ValueError()
            if not streaming_supported():
                raise ValueError()
        except Exception:
            event('error', message='Invalid streaming configuration or missing H.264/AAC/RTMP plugins.')
            raise SystemExit(1)
        raise SystemExit(Recorder(args).run())
    if args.archive:
        parser.error('Archive requires streaming mode.')
    if not args.output or not Path(args.output).is_absolute() or Path(args.output).exists():
        parser.error('A new absolute output path is required.')
    if args.replay_seconds and (args.codec != 'vp8' or not shutil.which('ffmpeg')):
        parser.error('Replay requires VP8 and ffmpeg.')
    raise SystemExit(Recorder(args).run())
