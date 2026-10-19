// SPDX-License-Identifier: GPL-3.0-or-later
// Redline presentation; CoreCtrl attribution retained in credits.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Pane {
 background: Rectangle { color: redlineAppearance.color("#25252b", redlineAppearance.revision); border.color: redlineAppearance.color("#414147", redlineAppearance.revision) }
 ColumnLayout {
  anchors.fill: parent; anchors.margins: 26; spacing: 18
  Label { text: redlineAppearance.text(("REDLINE"), redlineAppearance.revision); font.pixelSize: 32; font.bold: true; color: redlineAppearance.color("#ed003e", redlineAppearance.revision) }
  Label { text: redlineAppearance.text(("Linux Graphics Edition · " + appInfo.version), redlineAppearance.revision); color: redlineAppearance.color("#aaaab0", redlineAppearance.revision) }
  Label { text: redlineAppearance.text(("AMD Software: Adrenalin Edition inspired interface. Not affiliated with AMD."), redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; color: redlineAppearance.color("#bbb", redlineAppearance.revision); font.pixelSize: 14 }
  Label { text: redlineAppearance.text(("Hardware profiles, GPU / CPU controls and live monitoring in one application."), redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; color: redlineAppearance.color("#bbb", redlineAppearance.revision); font.pixelSize: 14 }
  Rectangle { Layout.fillWidth: true; height: 1; color: redlineAppearance.color("#3c3c42", redlineAppearance.revision) }
  Label { text: redlineAppearance.text(("Open-source credits"), redlineAppearance.revision); color: redlineAppearance.color("#eee", redlineAppearance.revision); font.pixelSize: 13 }
  Label { text: redlineAppearance.text(("Hardware core derived from CoreCtrl, © Juan Palacios and contributors. GPL-3.0-or-later. GPU engine derived from LACT, © Ilya Zlobintsev and contributors (MIT). Original notices are included in the source."), redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; color: redlineAppearance.color("#9999a1", redlineAppearance.revision); font.pixelSize: 12 }
  Item { Layout.fillHeight: true }
 }
}
