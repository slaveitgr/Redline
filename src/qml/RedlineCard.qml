// SPDX-License-Identifier: GPL-3.0-or-later
// Redline fork, 2026.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id: card
 color: redlineAppearance.color("#252527", redlineAppearance.revision)
 property string heading: ""
 default property alias body: content.data
 ColumnLayout {
  anchors.fill: parent; spacing: 0
  Rectangle {
   Layout.fillWidth: true; Layout.preferredHeight: 30; color: redlineAppearance.color("#080809", redlineAppearance.revision)
   Label { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: redlineAppearance.text((card.heading), redlineAppearance.revision); color: redlineAppearance.color("#ddd", redlineAppearance.revision); font.pixelSize: 11 }
  }
  Item { id: content; Layout.fillWidth: true; Layout.fillHeight: true }
 }
}
