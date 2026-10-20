#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Explicit portal-selected local recording; never captures on startup."""
import argparse
import base64
import math
import re
import stat
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


def add_preview(pipeline, upstream, on_preview=None):
    def element(name, instance=None):
        item=Gst.ElementFactory.make(name,instance)
        if item is None:raise RuntimeError('Missing preview plugin: '+name)
        pipeline.add(item);return item
    def link(chain):
        for left,right in zip(chain,chain[1:]):
            if not left.link(right):raise RuntimeError('Could not connect camera preview.')
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
    link([upstream, branch, element('videoconvert'), preview_scale, preview_rate, preview_caps, jpeg, sink])


def read_initial_config(fd=None):
    fd=sys.stdin.fileno() if fd is None else fd
    data=bytearray()
    while len(data)<=8192:
        byte=os.read(fd,1)
        if byte==b'\n':return json.loads(data)
        if not byte:raise ValueError('Missing streaming configuration.')
        data.extend(byte)
    raise ValueError('Streaming configuration is too large.')


def camera_config(config):
    if not isinstance(config,dict):raise ValueError('Invalid camera settings.')
    result=dict(config)
    device=result.get('device','')
    if not isinstance(device,str) or not re.fullmatch(r'/dev/video[0-9]+',device):raise ValueError('Choose a local V4L2 camera.')
    if not stat.S_ISCHR(os.stat(device).st_mode):raise ValueError('Camera device is unavailable.')
    if result.get('resolution','auto') not in ('auto','640x480','1280x720'):raise ValueError('Invalid camera resolution.')
    for key,default in [('x',.68),('y',.62),('width',.28),('height',.32),('opacity',1)]:
        value=float(result.get(key,default))
        if not math.isfinite(value) or not 0<=value<=1:raise ValueError('Invalid camera geometry.')
        result[key]=value
    return result


def set_camera_geometry(pipeline, config):
    compositor=pipeline.get_by_name('scene-compositor')
    if compositor is None:
        if config.get('enabled',False):raise ValueError('Camera was not enabled when capture started.')
        return
    pad=compositor.get_static_pad('sink_1')
    caps=pipeline.get_by_name('output-caps').get_static_pad('src').get_current_caps()
    if not caps:return
    shape=caps.get_structure(0);width,height=shape.get_value('width'),shape.get_value('height')
    w=max(.02,min(1,float(config.get('width',.28))));h=max(.02,min(1,float(config.get('height',.32))))
    pad.set_property('width',max(1,int(width*w)));pad.set_property('height',max(1,int(height*h)))
    pad.set_property('xpos',int(width*max(0,min(1-w,float(config.get('x',.68))))))
    pad.set_property('ypos',int(height*max(0,min(1-h,float(config.get('y',.62))))))
    pad.set_property('alpha',max(0,min(1,float(config.get('opacity',1)))) if config.get('enabled',False) else 0)


def add_camera_source(pipeline, config, destination, synthetic=False):
    def add(name,instance=None):
        element=Gst.ElementFactory.make(name,instance)
        if element is None:raise RuntimeError('Missing camera plugin: '+name)
        pipeline.add(element);return element
    source=add('videotestsrc' if synthetic else 'v4l2src','camera-source')
    if synthetic:
        source.set_property('pattern',4);source.set_property('num-buffers',120)
    else:
        source.set_property('device',config['device']);source.set_property('do-timestamp',True)
    decoder=add('decodebin','camera-decoder')
    previous=source
    if config.get('resolution','auto')!='auto':
        width,height=map(int,config['resolution'].split('x'))
        caps=add('capsfilter');caps.set_property('caps',Gst.Caps.from_string(f'video/x-raw,width={width},height={height};image/jpeg,width={width},height={height}'))
        if not source.link(caps):raise RuntimeError('Camera format unavailable.')
        previous=caps
    if not previous.link(decoder):raise RuntimeError('Camera decoder unavailable.')
    convert=add('videoconvert','camera-convert');queue=add('queue','camera-queue')
    convert.link(queue)
    def decoded(unused,pad):
        caps=pad.get_current_caps()
        if caps and caps.get_structure(0).get_name().startswith('video/') and not convert.get_static_pad('sink').is_linked():pad.link(convert.get_static_pad('sink'))
    decoder.connect('pad-added',decoded)
    if destination:
        pad=destination.request_pad_simple('sink_%u');pad.set_property('zorder',1);pad.set_property('sizing-policy',1)
        if queue.get_static_pad('src').link(pad)!=Gst.PadLinkReturn.OK:raise RuntimeError('Could not compose camera.')
    return queue


def camera_preview_pipeline(config,synthetic=False,on_preview=None):
    pipeline=Gst.Pipeline.new('redline-camera-preview')
    output=add_camera_source(pipeline,config,None,synthetic)
    add_preview(pipeline,output,on_preview)
    return pipeline


def audio_devices():
    """Enumerate PulseAudio/PipeWire-Pulse metadata; never start a source."""
    provider = Gst.DeviceProviderFactory.get_by_name('pulsedeviceprovider')
    if provider is None or not provider.start():
        raise ValueError('Audio server is unavailable. Check PulseAudio or PipeWire-Pulse.')
    result=[]
    try:
        for device in provider.get_devices():
            if device.get_device_class() != 'Audio/Source': continue
            source=device.create_element(None)
            name=source.get_property('device') if source else None
            props=device.get_properties()
            monitor=bool(props and props.has_field('device.class') and props.get_value('device.class')=='monitor')
            if name:
                result.append({'id':name,'label':device.get_display_name(),'kind':'system' if monitor or name.endswith('.monitor') else 'microphone'})
    finally: provider.stop()
    return result


def audio_settings(config=None):
    config=config or {}
    result={}
    for kind in ('system','microphone'):
        device=config.get(kind+'Device','')
        volume=float(config.get(kind+'Volume',1.0))
        mute=config.get(kind+'Mute',False)
        if not isinstance(device,str) or len(device)>512 or any(ord(c)<32 for c in device) or not math.isfinite(volume) or not 0<=volume<=1 or not isinstance(mute,bool):
            raise ValueError('Invalid audio settings.')
        result.update({kind+'Device':device,kind+'Volume':volume,kind+'Mute':mute})
    return result


def validate_audio_devices(config, system, microphone, devices=None):
    devices=audio_devices() if devices is None else devices
    for kind,enabled in (('system',system),('microphone',microphone)):
        selected=config[kind+'Device']
        if enabled and selected and not any(d['id']==selected and d['kind']==kind for d in devices):
            raise ValueError('Selected '+kind+' device is unavailable. Refresh devices and select it again. Capture was not started.')


def add_audio_inputs(pipeline, system, microphone, config=None, synthetic=False, meters=False):
    config=audio_settings(config)
    def element(factory,name=None):
        e=Gst.ElementFactory.make(factory,name)
        if e is None: raise RuntimeError('Missing audio plugin: '+factory)
        pipeline.add(e);return e
    mixer=element('audiomixer','audio-mixer')
    for kind,enabled in (('system',system),('microphone',microphone)):
        if not enabled: continue
        source=element('audiotestsrc' if synthetic else 'pulsesrc',kind+'-audio')
        if synthetic:
            source.set_property('num-buffers',45);source.set_property('freq',440.0 if kind=='system' else 880.0)
        else:
            selected=config[kind+'Device'] or ('@DEFAULT_MONITOR@' if kind=='system' else '@DEFAULT_SOURCE@')
            source.set_property('device',selected)
            source.set_property('stream-properties',Gst.Structure.new_from_string('props,media.role=(string)Production'))
        volume=element('volume',kind+'-volume');volume.set_property('volume',config[kind+'Volume']);volume.set_property('mute',config[kind+'Mute'])
        caps=element('capsfilter');caps.set_property('caps',Gst.Caps.from_string('audio/x-raw,rate=48000,channels=2'))
        chain=[source,element('audioconvert'),element('audioresample'),caps,volume]
        if meters:
            level=element('level',kind+'-level');level.set_property('interval',Gst.SECOND//5);chain.append(level)
        chain += [element('queue'),mixer]
        for left,right in zip(chain,chain[1:]):
            if not left.link(right): raise RuntimeError('Could not connect audio inputs.')
    return mixer


def audio_preview_pipeline(system,microphone,config=None,synthetic=False):
    if not system and not microphone: raise ValueError('Enable system audio or microphone before testing.')
    pipeline=Gst.Pipeline.new('redline-audio-test')
    mixer=add_audio_inputs(pipeline,system,microphone,config,synthetic,True)
    sink=Gst.ElementFactory.make('fakesink','audio-test-sink');sink.set_property('sync',False);pipeline.add(sink);mixer.link(sink)
    return pipeline


def apply_audio(pipeline,config):
    config=audio_settings(config)
    for kind in ('system','microphone'):
        volume=pipeline.get_by_name(kind+'-volume')
        if volume:
            volume.set_property('volume',config[kind+'Volume']);volume.set_property('mute',config[kind+'Mute'])


def make_pipeline(output, fps=30, audio=False, fd=None, node=None, synthetic=False, serial=None,
                  codec='vp8', bitrate=8, resolution='native', microphone=False, replay=False, stream=None, audio_bitrate=128, archive=False, preview=False, on_preview=None, overlay_file=None, camera=None, synthetic_camera=False, audio_config=None):
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
    caps = element('capsfilter', 'output-caps')
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
    base_video = [source, convert, scale, rate, caps]
    if camera and camera.get("enabled",True):
        compositor=element('compositor','scene-compositor');compositor.set_property('background',1)
        screen_pad=compositor.request_pad_simple('sink_%u');screen_pad.set_property('zorder',0)
        screen_queue=element('queue');base_video[-1].link(screen_queue)
        if screen_queue.get_static_pad('src').link(screen_pad)!=Gst.PadLinkReturn.OK:raise RuntimeError('Could not compose screen.')
        link(base_video)
        add_camera_source(pipeline,camera,compositor,synthetic_camera)
        composition_caps=element('capsfilter','composition-caps')
        composition_caps.set_property('caps',Gst.Caps.from_string(f'video/x-raw,framerate={fps}/1'))
        def compose_size(*unused):
            current=caps.get_static_pad('src').get_current_caps()
            if current:
                shape=current.get_structure(0)
                composition_caps.set_property('caps',Gst.Caps.from_string(f"video/x-raw,width={shape.get_value('width')},height={shape.get_value('height')},framerate={fps}/1,pixel-aspect-ratio=1/1"))
                set_camera_geometry(pipeline,camera)
        caps.get_static_pad('src').connect('notify::caps',compose_size)
        base_video=[compositor,element('videoconvert'),composition_caps]
    if overlay_file:
        overlay = element('gdkpixbufoverlay', 'scene-overlay')
        overlay.set_property('location', str(overlay_file))
        def resize(pad, unused):
            current = pad.get_current_caps()
            if current:
                shape = current.get_structure(0)
                overlay.set_property('overlay-width', shape.get_value('width'))
                overlay.set_property('overlay-height', shape.get_value('height'))
        caps.get_static_pad('src').connect('notify::caps', resize)
        base_video += [element('videoconvert'), overlay, element('videoconvert')]
    link(base_video)
    video_source = base_video[-1]
    if preview:
        video_source = element('tee', 'preview-fork')
        link([base_video[-1], video_source])
        add_preview(pipeline, video_source, on_preview)
    video = [video_source] + ([element('queue')] if preview else []) + [encoder]
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
    if audio or microphone:
        mixer = add_audio_inputs(pipeline,audio,microphone,audio_config,synthetic,preview)
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
        self.command_buffer = b''
        self.stopping = False
        self.failed = False
        self.replay_dir = tempfile.TemporaryDirectory(prefix='redline-replay-') if args.replay_seconds else None
        self.fragments = deque()
        self.export_thread = None
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self.stop)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self.stop)
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, self.command)

    def command(self, stream, condition):
        try:data=os.read(stream.fileno(),65536)
        except OSError:data=b''
        if not data:
            self.stop();return False
        self.command_buffer+=data
        while b'\n' in self.command_buffer:
            line,self.command_buffer=self.command_buffer.split(b'\n',1)
            command=line.decode('utf-8','replace').strip()
            if len(command)>16384:
                event('scene-rejected',message='Scene command is too large.');continue
            if command.startswith('{') and not self.stopping:
                try:
                    config=json.loads(command)
                    if config.get('command')=='audio':
                        if self.pipeline is None: raise ValueError('Audio is not ready.')
                        apply_audio(self.pipeline,config);event('audio-applied')
                    else:self.apply_scene(config)
                except Exception as error:event('scene-rejected',message=str(error)[:200])
            elif command=='save-replay' and self.replay_dir and not self.stopping:self.save_replay()
            elif command=='stop':
                self.stop();return False
        if len(self.command_buffer)>16384:self.command_buffer=b''
        if condition & GLib.IO_HUP:
            self.stop();return False
        return True

    def apply_scene(self, config):
        if not self.pipeline or config.get('command')!='scene':raise ValueError('Capture is not ready.')
        overlay=self.pipeline.get_by_name('scene-overlay')
        if overlay is None:raise ValueError('Live scenes were unavailable at capture start.')
        path=Path(config.get('overlay',''))
        if not path.is_absolute() or path.parent!=Path(self.args.overlay_file).parent or path.suffix!='.png' or not path.is_file():raise ValueError('Invalid scene overlay.')
        camera=config.get('camera',{'enabled':False})
        for key in ('x','y','width','height','opacity'):
            value=float(camera.get(key,0))
            if not math.isfinite(value) or not 0<=value<=1:raise ValueError('Invalid camera geometry.')
        set_camera_geometry(self.pipeline,camera)
        if getattr(self.args,'camera',None):self.args.camera.update({key:camera[key] for key in ('enabled','x','y','width','height','opacity') if key in camera})
        overlay.set_property('location',str(path))
        event('scene-applied',serial=int(config.get('serial',0)))

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
        self.pipeline = make_pipeline(str(Path(self.replay_dir.name) / "chunk-%06d.webm") if self.replay_dir else self.args.output, self.args.fps, self.args.audio, self.fd, streams[0][0], serial=streams[0][1].get('pipewire-serial'), codec=self.args.codec, bitrate=self.args.bitrate, resolution=self.args.resolution, microphone=self.args.microphone, replay=bool(self.replay_dir), stream=getattr(self.args,"stream_location",None), audio_bitrate=getattr(self.args,"audio_bitrate",128), archive=getattr(self.args,"archive",False), preview=getattr(self.args,"preview",False), overlay_file=getattr(self.args,"overlay_file",None), camera=getattr(self.args,"camera",None), audio_config=getattr(self.args,"audio_config",None))
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
            self.error('An audio device became unavailable. Capture stopped; reconnect it and select it again.' if message.src is not None and message.src.get_name() in ('system-audio','microphone-audio') else 'Stream connection or encoding failed. Check the server, key and network.' if getattr(self.args, 'stream', False) else error.message)
        elif message.type == Gst.MessageType.STATE_CHANGED and message.src == self.pipeline:
            old, new, pending = message.parse_state_changed()
            if new == Gst.State.PLAYING:
                event('audio-preview' if getattr(self.args,'audio_preview',False) else 'camera-preview' if getattr(self.args,'camera_preview',False) else 'streaming' if getattr(self.args,'stream',False) else 'recording', output=self.args.output)
        elif message.type == Gst.MessageType.EOS:
            if getattr(self,'audio_failure',None):
                self.error(self.audio_failure);return
            event('audio-stopped' if getattr(self.args,'audio_preview',False) else 'camera-stopped' if getattr(self.args,'camera_preview',False) else 'stream-stopped' if getattr(self.args,'stream',False) else 'buffer-stopped' if self.replay_dir else 'saved', output=self.args.output, archived=bool(getattr(self.args,'archive',False)))
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

    def check_audio_devices(self):
        if self.stopping or self.failed:return False
        config=getattr(self.args,'audio_config',{})
        if not any(config.get(k+'Device') for k in ('system','microphone')):return False
        try:validate_audio_devices(config,self.args.audio,self.args.microphone)
        except Exception:
            self.audio_failure='Selected audio device disconnected. Capture stopped; reconnect it and select it again.'
            self.stop();return False
        return True

    def run(self):
        self.audio_failure=None
        poll=GLib.timeout_add_seconds(2,self.check_audio_devices) if (getattr(self.args,'audio',False) or getattr(self.args,'microphone',False)) else None
        try:
            if getattr(self.args,'audio_preview',False):
                self.pipeline=audio_preview_pipeline(self.args.audio,self.args.microphone,self.args.audio_config)
                bus=self.pipeline.get_bus();bus.add_signal_watch();bus.connect('message',self.bus_message)
                if self.pipeline.set_state(Gst.State.PLAYING)==Gst.StateChangeReturn.FAILURE:raise RuntimeError('Could not open audio test.')
            elif getattr(self.args,'camera_preview',False):
                self.pipeline=camera_preview_pipeline(self.args.camera)
                bus=self.pipeline.get_bus();bus.add_signal_watch();bus.connect('message',self.bus_message)
                if self.pipeline.set_state(Gst.State.PLAYING)==Gst.StateChangeReturn.FAILURE:raise RuntimeError('Could not open camera preview.')
            else:
                self.connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
                event('selecting')
                self.request('CreateSession', '(a{sv})', (), {'session_handle_token': GLib.Variant('s', 'redline_' + uuid.uuid4().hex)}, self.created)
            self.loop.run()
        except Exception as error:
            self.error('Stream setup failed.' if getattr(self.args,'stream',False) else str(error))
        finally:
            if poll is not None:
                source=GLib.MainContext.default().find_source_by_id(poll)
                if source:source.destroy()
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
    parser.add_argument('--audio-devices',action='store_true')
    parser.add_argument('--audio-file')
    parser.add_argument('--audio-preview',action='store_true')
    parser.add_argument('--stream', action='store_true')
    parser.add_argument('--archive', action='store_true')
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--overlay-file')
    parser.add_argument('--camera-file')
    parser.add_argument('--camera-preview',action='store_true')
    parser.add_argument('--camera-device')
    parser.add_argument('--camera-resolution',choices=['auto','640x480','1280x720'],default='auto')
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
    if args.audio_devices:
        try:event('audio-devices',devices=audio_devices())
        except Exception as error:event('audio-devices',devices=[],message=str(error))
        raise SystemExit(0)
    if args.check:
        required = ['pipewiresrc', 'videoconvert', 'videoscale', 'videorate', 'filesink']
        missing = [name for name in required if not Gst.ElementFactory.find(name)]
        codecs = available_codecs()
        event('capabilities', camera=all(Gst.ElementFactory.find(n) for n in ['v4l2src','decodebin','compositor']), scenes=bool(Gst.ElementFactory.find('gdkpixbufoverlay')), preview=all(Gst.ElementFactory.find(n) for n in ('tee','queue','jpegenc','appsink','level')), streaming=streaming_supported(), supported=not missing and bool(codecs), codecs=codecs, missing=missing, replay=bool(shutil.which('ffmpeg') and Gst.ElementFactory.find('splitmuxsink')), audio=all(Gst.ElementFactory.find(n) for n in ['pulsesrc', 'audiomixer', 'audioconvert', 'audioresample', 'volume']))
        raise SystemExit(bool(missing) or not codecs)
    if os.getenv('REDLINE_READ_ONLY') is not None:
        parser.error('Recording is disabled in UI preview.')
    args.audio_config=audio_settings()
    try:
        if args.audio_file:args.audio_config=audio_settings(json.loads(Path(args.audio_file).read_text()[:8192]))
        if args.audio or args.microphone:validate_audio_devices(args.audio_config,args.audio,args.microphone)
    except Exception as error:
        event('error',message=str(error));raise SystemExit(1)
    if args.audio_preview:raise SystemExit(Recorder(args).run())
    args.camera=None
    if args.camera_file or args.camera_preview:
        try:
            config=json.loads(Path(args.camera_file).read_text()[:8192]) if args.camera_file else {'device':args.camera_device,'resolution':args.camera_resolution}
            args.camera=camera_config(config)
        except Exception:
            event('error',message='Camera settings or device are unavailable. Check device selection and permissions.')
            raise SystemExit(1)
    if args.camera_preview:
        raise SystemExit(Recorder(args).run())
    if args.stream:
        try:
            config = read_initial_config()
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
