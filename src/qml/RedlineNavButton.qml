// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import "RedlineDesign.js" as Design
Button {
 id:control
 property bool selected:false
 property bool secondary:false
 property bool compact:false
 implicitHeight:secondary?Design.subnavigationHeight:Design.navigationHeight
 leftPadding:compact?12:16;rightPadding:compact?12:16;hoverEnabled:true
 Accessible.name:redlineAppearance.text(text,redlineAppearance.revision)
 contentItem:Label {
  text:redlineAppearance.text(control.text,redlineAppearance.revision)
  font.pixelSize:control.secondary?14:control.compact?16:18
  color:redlineAppearance.color(control.selected || control.hovered?"#eeeeee":"#969696",redlineAppearance.revision)
  verticalAlignment:Text.AlignVCenter
 }
 background:Rectangle {
  color:control.down?redlineAppearance.color("#353535",redlineAppearance.revision):control.hovered?redlineAppearance.color("#303030",redlineAppearance.revision):"transparent"
  border.width:control.activeFocus?1:0;border.color:redlineAppearance.color("#707070",redlineAppearance.revision)
  Rectangle {anchors.bottom:parent.bottom;anchors.left:parent.left;anchors.right:parent.right;anchors.leftMargin:16;anchors.rightMargin:16;height:3;color:Design.accent;visible:control.selected}
 }
}
