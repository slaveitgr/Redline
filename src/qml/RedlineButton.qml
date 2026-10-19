// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import "RedlineDesign.js" as Design
Button {
 id: control
 property bool accent: false
 implicitHeight: Design.buttonHeight
 leftPadding: 16; rightPadding: 16
 hoverEnabled: true
 contentItem: Label { text: redlineAppearance.text((control.text), redlineAppearance.revision); color: control.accent && control.enabled ? "white" : control.enabled ? redlineAppearance.color("#eeeeef", redlineAppearance.revision) : redlineAppearance.color("#78787f", redlineAppearance.revision); font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
 background: Rectangle { color: !control.enabled ? redlineAppearance.color("#252529", redlineAppearance.revision) : control.accent ? (control.hovered ? redlineAppearance.color("#ed1748", redlineAppearance.revision) : redlineAppearance.color(Design.accent, redlineAppearance.revision)) : (control.hovered ? redlineAppearance.color("#38383e", redlineAppearance.revision) : redlineAppearance.color("#29292d", redlineAppearance.revision)); radius: 0; border.color: control.accent ? "transparent" : redlineAppearance.color("#303034", redlineAppearance.revision) }
}
