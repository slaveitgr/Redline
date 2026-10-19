// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id: group
 property string heading: ""
 property bool collapsible: false
 property bool expanded: true
 default property alias rows: contents.data
 spacing: 1
 Layout.fillWidth: true
 ToolButton {
  visible:group.heading.length>0;Layout.fillWidth:true;implicitHeight:42;leftPadding:0
  contentItem:Label{text:redlineAppearance.text(((group.collapsible?(group.expanded?"⌄  ":"›  "):"")+group.heading), redlineAppearance.revision);color:redlineAppearance.color("#d1d1d6", redlineAppearance.revision);font.pixelSize:14;verticalAlignment:Text.AlignVCenter}
  background:Rectangle{color:"transparent"}
  onClicked:if(group.collapsible)group.expanded=!group.expanded
 }
 ColumnLayout {id:contents;visible:!group.collapsible || group.expanded;Layout.fillWidth:true;spacing:1}
}
