# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import pathlib
import unittest
spec = importlib.util.spec_from_file_location('display', pathlib.Path(__file__).parents[1] / 'tools/redline-display.py')
display = importlib.util.module_from_spec(spec)
spec.loader.exec_module(display)


def state():
    a = ('DP-1', 'vendor', 'model', 'serial')
    b = ('HDMI-1', 'vendor', 'second', 'serial')
    modes = [('a', 1920, 1080, 60., 1., [1., 1.5], {'is-current': True}),
             ('a-vrr', 1920, 1080, 60., 1., [1., 1.5], {'refresh-rate-mode': 'variable'})]
    return (7, [(a, modes, {'color-mode': 2, 'supported-color-modes': [0, 2]}),
                (b, modes, {'color-mode': 0})],
            [(0, 0, 1., 0, True, [a], {}), (1920, 0, 1., 1, False, [b], {})],
            {'layout-mode': 1, 'supports-changing-layout-mode': True})


class DisplayTests(unittest.TestCase):
    def test_only_advertised_modes_scales_and_colors(self):
        for args in [('missing', 'a', 1., 0), ('DP-1', 'injected', 1., 0),
                     ('DP-1', 'a', 9., 0), ('DP-1', 'a', 1., 1)]:
            with self.assertRaises(ValueError):
                display.configuration(state(), *args)

    def test_preserves_other_monitor_rotation_primary_and_color(self):
        config, props = display.configuration(state(), 'DP-1', 'a-vrr', 1.5, 2)
        self.assertEqual(config[0][:5], (0, 0, 1.5, 0, True))
        self.assertEqual(config[0][5][0][1], 'a-vrr')
        self.assertEqual(config[0][5][0][2]['color-mode'].unpack(), 2)
        self.assertEqual(config[1][:5], (1920, 0, 1., 1, False))
        self.assertEqual(config[1][5][0][:2], ('HDMI-1', 'a'))
        self.assertEqual(props['layout-mode'].unpack(), 1)
        # Real D-Bus signature must accept the generated configuration.
        display.GLib.Variant('(uua(iiduba(ssa{sv}))a{sv})', (7, 0, config, props))

    def test_mirrored_and_disabled_display_rejected(self):
        s = state()
        s[2][0][5].append(s[1][1][0])
        with self.assertRaises(ValueError):
            display.configuration(s, 'DP-1', 'a', 1., 0)
        s = state()
        s[2].pop(0)
        with self.assertRaises(ValueError):
            display.configuration(s, 'DP-1', 'a', 1., 0)

    def test_vrr_capability_and_active_state(self):
        monitors = display.describe(state())['monitors']
        self.assertTrue(monitors[0]['active'])
        self.assertTrue(monitors[0]['modes'][1]['variable'])
        self.assertFalse(monitors[0]['modes'][0]['variable'])
        self.assertEqual(monitors[0]['color'], 2)


if __name__ == '__main__':
    unittest.main()
