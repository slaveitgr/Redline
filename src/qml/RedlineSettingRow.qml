// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id: row
 property string title: redlineAppearance.text((""), redlineAppearance.revision)
 property string description: ""
 property string kind: "info"
 property var currentValue: ""
 property var choices: []
 property bool supported: true
 property bool showStateLabel:true
 property string reason: ""
 property string actionText: "Open ›"
 signal requested(var value)
 color: redlineAppearance.color("#252528", redlineAppearance.revision)
 implicitHeight: Math.max(58, rowLabels.implicitHeight+24, valueLabel.visible?valueLabel.implicitHeight+24:0)
 Layout.fillWidth: true
 ToolTip.visible: hover.hovered && reason.length>0
 ToolTip.text: reason
 HoverHandler { id: hover }
 RowLayout {
  anchors.fill: parent; anchors.margins: 12; spacing: 14
  ColumnLayout {
   id: rowLabels; Layout.fillWidth:true;spacing:4
   Label {text:redlineAppearance.text((row.title), redlineAppearance.revision);color:redlineAppearance.color("#dddddf", redlineAppearance.revision);font.pixelSize:13;wrapMode:Text.WordWrap;Layout.fillWidth:true}
   Label {visible:row.description.length>0;text:redlineAppearance.text((row.description), redlineAppearance.revision);color:redlineAppearance.color("#909096", redlineAppearance.revision);font.pixelSize:11;wrapMode:Text.WordWrap;Layout.fillWidth:true}
  }
  Label {
   id:valueLabel
   maximumLineCount:3;elide:Text.ElideRight
   visible:row.showStateLabel && (row.kind==="info" || row.kind==="switch")
   text:redlineAppearance.text((row.kind==="switch" ? (!row.supported?"Unavailable":Boolean(row.currentValue)?"Enabled":"Disabled") : String(row.currentValue || "Not reported")), redlineAppearance.revision)
   color:row.supported?redlineAppearance.color("#babac1", redlineAppearance.revision):redlineAppearance.color("#88888f", redlineAppearance.revision);font.pixelSize:12;wrapMode:Text.WordWrap
   Layout.preferredWidth:row.kind==="switch"?74:Math.min(240,row.width*.45)
  }
  Switch {Accessible.name:row.title;objectName:row.objectName+"_switch";visible:row.kind==="switch";enabled:row.supported;checked:row.supported && Boolean(row.currentValue);onToggled:row.requested(checked)}
  ComboBox {
   Accessible.name:row.title
   visible:row.kind==="choice";Layout.preferredWidth:visible?Math.min(220,row.width*.43):0
   model:row.choices;enabled:row.supported
   displayText:redlineAppearance.text(currentText,redlineAppearance.revision)
   delegate:ItemDelegate{required property string modelData;required property int index;width:parent?parent.width:200;text:redlineAppearance.text(modelData,redlineAppearance.revision)}
   currentIndex:Math.max(0,row.choices.indexOf(String(row.currentValue)))
   onActivated:row.requested(currentText)
  }
  RedlineButton {Accessible.name:row.title+" "+row.actionText;visible:row.kind==="action";text:row.actionText;enabled:row.supported;onClicked:row.requested(true)}
 }
}
