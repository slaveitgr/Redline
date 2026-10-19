// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id:page
 property string subpage:"Chat"
 property var store
 property string selectedModel:{var r=store.revision;return store.read("ai.model","")}
 property bool includeSensors:false
 property var conversation:[]
 property var suggestions:["What is my GPU temperature?","How can I reduce input lag on Linux?","Explain GameMode and Gamescope","How does MangoHud work?"]
 function tr(s){return redlineAppearance.text(s,redlineAppearance.revision)}
 function shade(s){return redlineAppearance.color(s,redlineAppearance.revision)}
 function selectModel(name){if(localAssistant.busy)return;if(selectedModel!==name){store.write("ai.model",name);transcript.clear();conversation=[]}}
 function draft(text){composer.text=tr(text);composer.forceActiveFocus()}
 function submit(){
  var text=composer.text.trim();if(!text || localAssistant.busy || localAssistant.models.indexOf(selectedModel)<0)return
  conversation=conversation.concat([{role:"user",content:text}]);transcript.append({role:"user",content:text});composer.clear()
  var context=includeSensors?"Current sensor snapshot: "+JSON.stringify(nativeDashboard.metrics)+". CPU: "+nativeDashboard.systemInfo.cpuName:"No live system snapshot supplied. Do not invent sensor readings."
  localAssistant.send(selectedModel,conversation,context)
 }
 ListModel {id:transcript}
 Connections {target:localAssistant;function onAnswered(text){page.conversation=page.conversation.concat([{role:"assistant",content:text}]);transcript.append({role:"assistant",content:text})}}
 ColumnLayout {
  anchors.fill:parent;anchors.margins:24;spacing:16
  RowLayout {
   Layout.fillWidth:true
   Label {text:page.tr(page.subpage==="Apps"?"Local AI models":"Redline Chat");font.pixelSize:25;color:page.shade("#eee");Layout.fillWidth:true}
   RedlineButton {text:"New chat";visible:page.subpage==="Chat";enabled:!localAssistant.busy && transcript.count>0;onClicked:{transcript.clear();page.conversation=[]}}
   RedlineButton {text:"Refresh models";enabled:!localAssistant.busy;onClicked:localAssistant.refresh()}
  }
  Label {text:page.tr("Local Ollama · conversations stay in this session. No model is downloaded automatically.");color:page.shade("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true}
  Rectangle {
   Layout.fillWidth:true;implicitHeight:64;color:page.shade("#252528")
   RowLayout {anchors.fill:parent;anchors.margins:12
    Label {text:page.tr("Model");color:page.shade("#ddd")}
    ComboBox {Layout.fillWidth:true;model:localAssistant.models;enabled:!localAssistant.busy;currentIndex:localAssistant.models.indexOf(page.selectedModel);displayText:currentIndex<0?page.tr("Select a local model"):currentText;onActivated:{page.selectModel(currentText)}}
    Label {text:page.tr(localAssistant.models.length?"Available":"Not connected");color:page.shade("#aaa")}
   }
  }
  Label {visible:localAssistant.error.length>0;text:page.tr(localAssistant.error);color:"#dd0031";wrapMode:Text.WordWrap;Layout.fillWidth:true}
  StackLayout {
   Layout.fillWidth:true;Layout.fillHeight:true;currentIndex:page.subpage==="Apps"?1:0
   ColumnLayout {
    spacing:12
    Item {
     visible:transcript.count===0;Layout.fillWidth:true;Layout.fillHeight:true
     ColumnLayout {
      anchors.centerIn:parent;width:Math.min(parent.width,650);spacing:18
      Label {text:"R";font.bold:true;font.pixelSize:64;color:"#dd0031";Layout.alignment:Qt.AlignHCenter}
      Label {text:page.tr("Your Linux gaming assistant");font.pixelSize:26;color:page.shade("#eee");Layout.alignment:Qt.AlignHCenter}
      Label {text:page.tr("Ask about graphics, games and your hardware. Connect a local model to start chatting.");color:page.shade("#aaa");wrapMode:Text.WordWrap;Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter}
      GridLayout {columns:2;Layout.fillWidth:true;columnSpacing:10;rowSpacing:10
       Repeater {model:page.suggestions;RedlineButton {required property string modelData;text:modelData;Layout.fillWidth:true;onClicked:page.draft(modelData)}}
      }
     }
    }
    ListView {
     id:messages;visible:transcript.count>0;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:12;model:transcript
     ScrollBar.vertical:ScrollBar{}
     onCountChanged:Qt.callLater(function(){messages.positionViewAtEnd()})
     delegate:Rectangle {
      required property string role;required property string content
      width:messages.width-12;implicitHeight:messageColumn.implicitHeight+28;color:page.shade(role==="user"?"#282828":"#202020")
      ColumnLayout {id:messageColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:14;spacing:8
       Label {text:role==="user"?page.tr("You"):"Redline Chat";color:role==="user"?page.shade("#aaa"):"#dd0031";font.bold:true}
       TextEdit {text:content;textFormat:TextEdit.PlainText;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;color:page.shade("#eee");font.pixelSize:14;Layout.fillWidth:true;Layout.preferredHeight:contentHeight}
      }
     }
    }
    RowLayout {
     Layout.fillWidth:true
     CheckBox {text:page.tr("Include live hardware snapshot");checked:page.includeSensors;onToggled:page.includeSensors=checked}
     Item {Layout.fillWidth:true}
     BusyIndicator {running:localAssistant.busy;visible:running;Layout.preferredWidth:26;Layout.preferredHeight:26}
     RedlineButton {text:"Stop";visible:localAssistant.busy;onClicked:localAssistant.cancel()}
    }
    RowLayout {
     Layout.fillWidth:true
     TextField {id:composer;Layout.fillWidth:true;placeholderText:page.tr("Ask Redline Chat…");maximumLength:12000;enabled:!localAssistant.busy;onAccepted:page.submit()}
     RedlineButton {text:"Send";accent:true;enabled:!localAssistant.busy && composer.text.trim().length>0 && localAssistant.models.indexOf(page.selectedModel)>=0;onClicked:page.submit()}
    }
   }
   ScrollView {
    id:appsScroll;contentWidth:availableWidth;clip:true
    ColumnLayout {width:appsScroll.availableWidth;spacing:12
     Label {visible:localAssistant.models.length===0;text:page.tr("No local models detected. Start your Ollama service with an installed model, then choose Refresh models.");color:page.shade("#aaa");wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.margins:18}
     Repeater {model:localAssistant.models;Rectangle {
      required property string modelData;Layout.fillWidth:true;implicitHeight:90;color:page.shade("#252528")
      RowLayout {anchors.fill:parent;anchors.margins:18
       Label {text:modelData;color:page.shade("#eee");font.pixelSize:18;Layout.fillWidth:true;elide:Text.ElideRight}
       RedlineButton {text:"Use in Chat";enabled:!localAssistant.busy;onClicked:{page.selectModel(modelData);page.openChat()}}
      }
     }}
     Label {text:page.tr("Text chat is connected through Ollama. Document search and image generation are not connected yet.");color:page.shade("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.margins:18}
    }
   }
  }
 }
 signal openChat()
}
