// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ScrollView {
 id:page
 property var store
 property string message:""
 property var actions:[{id:"replay",label:"Save Instant Replay",value:"Ctrl+Shift+S"},{id:"record",label:"Start / Stop Recording",value:"Ctrl+Shift+R"},{id:"logging",label:"Start / Stop Metrics Logging",value:"Ctrl+Shift+L"},{id:"games",label:"Open Game Library",value:"Alt+G"},{id:"metrics",label:"Open Performance Metrics",value:"Alt+P"}]
 signal openOverlay()
 contentWidth:availableWidth;clip:true
 function save(action,value){
  var normalized=shortcutSupport.canonical(value)
  if(value.trim().length && !normalized.length){message="Use one key combination with Ctrl or Alt, or an F1–F12 key.";return}
  for(var i=0;i<actions.length;i++)if(actions[i].id!==action.id && normalized.length && shortcutSupport.canonical(store.read("keys."+actions[i].id,actions[i].value))===normalized){message="That shortcut is already assigned to another action.";return}
  store.write("keys."+action.id,normalized);message=normalized.length?"Shortcut saved.":"Shortcut disabled."
 }
 ColumnLayout {
  width:page.availableWidth;spacing:14
  Label{text:"Application Hotkeys";font.pixelSize:22;color:redlineAppearance.color("#eee",redlineAppearance.revision);Layout.margins:18}
  Label{text:"These shortcuts work while Redline has focus. They do not register global desktop shortcuts or replace the in-game MangoHud shortcut.";wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.leftMargin:18;Layout.rightMargin:18;color:redlineAppearance.color("#999",redlineAppearance.revision)}
  Repeater {
   model:page.actions
   Rectangle {
    required property var modelData
    Layout.fillWidth:true;Layout.leftMargin:18;Layout.rightMargin:18;implicitHeight:76;color:redlineAppearance.color("#252528",redlineAppearance.revision)
    RowLayout {
     anchors.fill:parent;anchors.margins:12
     Label{text:modelData.label;Layout.fillWidth:true;color:redlineAppearance.color("#ddd",redlineAppearance.revision)}
     TextField{id:sequence;Accessible.name:modelData.label+" shortcut";Layout.preferredWidth:200;text:{var r=page.store.revision;return page.store.read("keys."+modelData.id,modelData.value)} placeholderText:"Empty = disabled"}
     RedlineButton{text:"Save";onClicked:page.save(modelData,sequence.text)}
    }
   }
  }
  RowLayout {
   Layout.margins:18
   RedlineButton{text:"Restore defaults";onClicked:{for(var i=0;i<page.actions.length;i++)page.store.write("keys."+page.actions[i].id,page.actions[i].value);page.message="Default shortcuts restored."}}
   RedlineButton{text:"In-game Overlay Shortcut ›";onClicked:page.openOverlay()}
  }
  Label{text:page.message;visible:text.length>0;wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.margins:18;color:redlineAppearance.color("#ddd",redlineAppearance.revision)}
 }
}
