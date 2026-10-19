// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import "RedlineDesign.js" as Design
Button {
 id: control
 property string glyph
 property int imageSize: Design.iconSize
 property int badgeCount: 0
 implicitWidth: Design.navigationHeight
 implicitHeight: Design.navigationHeight
 hoverEnabled: true
 display: AbstractButton.IconOnly
 icon.source: "icons/"+glyph+".svg"
 icon.width: imageSize; icon.height: imageSize
 icon.color: !enabled ? shade("#505050") : checked || hovered ? shade("#ffffff") : shade("#a6a6a6")
 Accessible.name: redlineAppearance.text(control.text,redlineAppearance.revision)
 function shade(value){return redlineAppearance.color(value,redlineAppearance.revision)}
 background: Rectangle {
  color: control.down ? control.shade("#383838") : control.hovered ? control.shade("#303030") : "transparent"
  border.width: control.activeFocus ? 1 : 0
  border.color: control.shade("#8d8d8d")
  Rectangle {anchors.bottom:parent.bottom;anchors.horizontalCenter:parent.horizontalCenter;width:parent.width-24;height:3;visible:control.checked;color:Design.accent}
 }
 Rectangle {
  visible:control.badgeCount>0;width:20;height:20;radius:10;color:Design.accent
  anchors.right:parent.right;anchors.top:parent.top;anchors.rightMargin:7;anchors.topMargin:6
  Label {anchors.centerIn:parent;text:control.badgeCount>99?"99+":String(control.badgeCount);font.pixelSize:10;color:"white"}
 }
 ToolTip.visible:hovered
 ToolTip.text:redlineAppearance.text(control.text,redlineAppearance.revision)
}
