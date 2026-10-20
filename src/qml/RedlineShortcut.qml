// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
Shortcut {
 property var settingsStore
 property string action:""
 property string defaultSequence:""
 sequence:shortcutSupport.canonical(settingsStore.read("keys."+action,defaultSequence))
 context:Qt.ApplicationShortcut
 autoRepeat:false
}
