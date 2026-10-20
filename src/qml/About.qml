// SPDX-License-Identifier: GPL-3.0-or-later
// Redline presentation; CoreCtrl attribution retained in credits.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Pane {
 background: Rectangle { color: redlineAppearance.color("#25252b", redlineAppearance.revision); border.color: redlineAppearance.color("#414147", redlineAppearance.revision) }
 ColumnLayout {
  anchors.fill: parent; anchors.margins: 24; spacing: 12
  Label { text: redlineAppearance.text(("REDLINE"), redlineAppearance.revision); font.pixelSize: 32; font.bold: true; color: redlineAppearance.color("#ed003e", redlineAppearance.revision) }
  Label { text: redlineAppearance.text(("Open-Source AMD Adrenalin Alternative for Linux · " + appInfo.version), redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; font.pixelSize: 13; color: redlineAppearance.color("#aaaab0", redlineAppearance.revision) }
  Label { text: redlineAppearance.text(("An independent, open-source Linux alternative to AMD Software: Adrenalin Edition. Built for real Linux GPU and gaming workflows."), redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; color: redlineAppearance.color("#bbb", redlineAppearance.revision); font.pixelSize: 14 }
  Label { text: redlineAppearance.text(("GPU / CPU monitoring, supported tuning, profiles and gaming tools in one app. Full Adrenalin feature parity is not yet available."), redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; color: redlineAppearance.color("#bbb", redlineAppearance.revision); font.pixelSize: 14 }
  Label { text: redlineAppearance.text("Not affiliated with, endorsed by or sponsored by AMD.", redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; color: redlineAppearance.color("#9999a1", redlineAppearance.revision); font.pixelSize: 12 }
  Label {text:"Slave IT Solutions — Greece";font.pixelSize:18;font.bold:true;color:redlineAppearance.color("#eee",redlineAppearance.revision);Layout.fillWidth:true}
  Label {text:"info@slave.gr · slave.gr";color:redlineAppearance.color("#aaaab0",redlineAppearance.revision);font.pixelSize:13}
  Rectangle { Layout.fillWidth: true; height: 1; color: redlineAppearance.color("#3c3c42", redlineAppearance.revision) }
  Label { text: redlineAppearance.text(("Open-source credits"), redlineAppearance.revision); color: redlineAppearance.color("#eee", redlineAppearance.revision); font.pixelSize: 13 }
  Label { text: redlineAppearance.text(("Hardware core derived from CoreCtrl, © Juan Palacios and contributors. GPL-3.0-or-later. GPU engine derived from LACT, © Ilya Zlobintsev and contributors (MIT). Original notices are included in the source."), redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; color: redlineAppearance.color("#9999a1", redlineAppearance.revision); font.pixelSize: 12 }
  Item { Layout.fillHeight: true }
 }
}
