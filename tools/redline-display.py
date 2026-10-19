#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""GNOME display capability discovery and validated compositor configuration."""
import json
import os
import sys
from gi.repository import Gio, GLib

INTERFACE = 'org.gnome.Mutter.DisplayConfig'


def current_mode(monitor):
    return next((m for m in monitor[1] if m[6].get('is-current')), None)


def describe(state, allowed=True):
    monitors = []
    for spec, modes, props in state[1]:
        logical = next((l for l in state[2] if spec in l[5]), None)
        active = next((m for m in modes if m[6].get('is-current')), None)
        monitors.append(dict(connector=spec[0], name=props.get('display-name', spec[0]),
            active=active is not None and logical is not None,
            scale=logical[2] if logical else 1,
            mode=active[0] if active else '',
            color=props.get('color-mode', 0), colors=props.get('supported-color-modes', []),
            modes=[dict(id=m[0], width=m[1], height=m[2], hz=m[3], scales=m[5],
                variable=m[6].get('refresh-rate-mode') == 'variable') for m in modes]))
    return dict(supported=True, allowed=allowed, monitors=monitors)


def configuration(state, connector, mode_id, scale, color):
    """Preserve all active monitors, rotation, primary status and color modes."""
    physical = {m[0][0]: m for m in state[1]}
    target = physical.get(connector)
    if target is None:
        raise ValueError('Display disconnected. Refresh and try again.')
    mode = next((m for m in target[1] if m[0] == mode_id), None)
    if mode is None or not any(abs(scale - s) < 0.00001 for s in mode[5]):
        raise ValueError('This mode or scale is not supported by the display.')
    if color not in target[2].get('supported-color-modes', [target[2].get('color-mode', 0)]):
        raise ValueError('This color mode is not supported.')
    result, found = [], False
    for x, y, old_scale, transform, primary, specs, _ in state[2]:
        selected = any(s[0] == connector for s in specs)
        if selected and len(specs) != 1:
            raise ValueError('Mirrored displays must be configured together in desktop settings.')
        outputs = []
        for spec in specs:
            monitor = physical[spec[0]]
            old = current_mode(monitor)
            if old is None:
                raise ValueError('Display state changed. Refresh and try again.')
            props = {}
            if 'color-mode' in monitor[2]:
                props['color-mode'] = GLib.Variant('u', color if selected else monitor[2]['color-mode'])
            if 'is-underscanning' in monitor[2]:
                props['underscanning'] = GLib.Variant('b', monitor[2]['is-underscanning'])
            outputs.append((spec[0], mode_id if selected else old[0], props))
        result.append((x, y, scale if selected else old_scale, transform, primary, outputs))
        found |= selected
    if not found:
        raise ValueError('Enable this display in desktop settings first.')
    props = {}
    if state[3].get('supports-changing-layout-mode') and 'layout-mode' in state[3]:
        props['layout-mode'] = GLib.Variant('u', state[3]['layout-mode'])
    return result, props


def main():
    proxy = Gio.DBusProxy.new_for_bus_sync(Gio.BusType.SESSION, Gio.DBusProxyFlags.DO_NOT_AUTO_START,
        None, INTERFACE, '/org/gnome/Mutter/DisplayConfig', INTERFACE, None)
    shell = Gio.DBusProxy.new_for_bus_sync(Gio.BusType.SESSION, Gio.DBusProxyFlags.DO_NOT_AUTO_START,
        None, 'org.gnome.Shell', '/org/gnome/Shell', 'org.gnome.Shell', None)
    if not shell.get_name_owner():
        raise ValueError('GNOME Shell is required for display-change confirmation.')
    state = proxy.call_sync('GetCurrentState', None, 0, 5000, None).unpack()
    allowed = proxy.get_cached_property('ApplyMonitorsConfigAllowed')
    allowed = allowed.unpack() if allowed is not None else False
    if len(sys.argv) > 1:
        if sys.argv[1] not in ('--apply', '--verify') or len(sys.argv) != 6:
            raise ValueError('Invalid display request.')
        if not allowed:
            raise ValueError('The desktop does not allow display configuration.')
        if sys.argv[1] == '--apply' and os.getenv('REDLINE_READ_ONLY') is not None:
            raise ValueError('Display changes are disabled in preview mode.')
        config, props = configuration(state, sys.argv[2], sys.argv[3], float(sys.argv[4]), int(sys.argv[5]))
        def apply(method):
            proxy.call_sync('ApplyMonitorsConfig', GLib.Variant('(uua(iiduba(ssa{sv}))a{sv})',
                (state[0], method, config, props)), 0, 5000, None)
        apply(0)
        if sys.argv[1] == '--apply':
            apply(2)  # GNOME Shell owns the Keep Changes / automatic revert dialog.
        print(json.dumps(dict(ok=True)))
    else:
        print(json.dumps(describe(state, allowed)))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps(dict(supported=False, error=str(error)[:500])))
        sys.exit(1)
