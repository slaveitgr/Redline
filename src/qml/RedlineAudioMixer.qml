// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:mixer
 property var store
 property string systemKey:"rec.systemAudio"
 property string microphoneKey:"rec.microphone"
 property bool systemEnabled:false
 property bool microphoneEnabled:false
 Layout.fillWidth:true
 spacing:8
 function read(key,fallback){var r=store.revision;return store.read("audio."+key,fallback)}
 function write(key,value){store.write("audio."+key,value);captureBackend.setAudio(store.captureAudio())}
 Label {text:redlineAppearance.text("Audio mixer",redlineAppearance.revision);color:redlineAppearance.color("#ddd",redlineAppearance.revision);font.pixelSize:16}
 Repeater {
  model:[{kind:"system",title:"System audio",enabled:mixer.systemEnabled},{kind:"microphone",title:"Microphone",enabled:mixer.microphoneEnabled}]
  delegate:ColumnLayout {
   id:channel
   required property var modelData
   property string kind:modelData.kind
   property string selected:mixer.read(kind+"Device","")
   property var devices:captureBackend.audioDevices.filter(function(d){return d.kind===channel.kind})
   property var ids:[""].concat(devices.map(function(d){return d.id})).concat(selected!=="" && !devices.some(function(d){return d.id===channel.selected})?[selected]:[])
   property bool missing:selected!=="" && !devices.some(function(d){return d.id===channel.selected})
   property var labels:["System default"].concat(devices.map(function(d){return d.label})).concat(missing?["Unavailable: "+selected]:[])
   Layout.fillWidth:true
   CheckBox {text:channel.modelData.title;checked:channel.modelData.enabled;enabled:captureBackend.audioSupported && !captureBackend.active;onToggled:mixer.store.write(channel.kind==="system"?mixer.systemKey:mixer.microphoneKey,checked)}
   RedlineSettingRow {title:channel.modelData.title+" device";kind:"choice";choices:channel.labels;currentValue:channel.labels[channel.ids.indexOf(channel.selected)] || "System default";supported:!captureBackend.active && channel.modelData.enabled;onRequested:value=>mixer.write(channel.kind+"Device",channel.ids[channel.labels.indexOf(value)])}
   Label {visible:channel.missing;text:"Selected device unavailable — refresh or select another device.";color:"#dc9b63";wrapMode:Text.WordWrap;Layout.fillWidth:true}
   RowLayout {
    Layout.fillWidth:true
    Label {text:Math.round(level.value)+"%";color:redlineAppearance.color("#bbb",redlineAppearance.revision);Layout.preferredWidth:40}
    Slider {id:level;Accessible.name:channel.modelData.title+" volume";from:0;to:100;stepSize:1;value:Number(mixer.read(channel.kind+"Volume",100));Layout.fillWidth:true;enabled:channel.modelData.enabled && !captureBackend.cameraPreview;onMoved:mixer.write(channel.kind+"Volume",Math.round(value))}
    CheckBox {text:"Mute";checked:Boolean(mixer.read(channel.kind+"Mute",false));enabled:channel.modelData.enabled && !captureBackend.cameraPreview;onToggled:mixer.write(channel.kind+"Mute",checked)}
   }
   ProgressBar {Layout.fillWidth:true;from:0;to:1;value:channel.kind==="system"?captureBackend.systemLevel:captureBackend.microphoneLevel}
  }
 }
 ColumnLayout {
  Layout.fillWidth:true
  RedlineButton {Layout.fillWidth:true;text:"Refresh audio devices";enabled:!captureBackend.active;onClicked:captureBackend.refreshAudioDevices()}
  RedlineButton {Layout.fillWidth:true;text:captureBackend.audioPreview?"Stop audio test":"Test audio — no recording";enabled:!redlineReadOnly && captureBackend.audioSupported && (captureBackend.audioPreview || (!captureBackend.active && (mixer.systemEnabled || mixer.microphoneEnabled)));onClicked:{if(captureBackend.audioPreview)captureBackend.stop();else captureBackend.previewAudio({systemAudio:mixer.systemEnabled,microphone:mixer.microphoneEnabled,audioConfig:mixer.store.captureAudio()})}}
 }
 Label {text:captureBackend.audioDeviceMessage;visible:text.length>0;wrapMode:Text.WordWrap;color:"#dc9b63";Layout.fillWidth:true}
 Label {text:"Test opens only enabled sources, displays levels and saves no file. Stop the test before recording or streaming. Volume and mute affect Redline only.";wrapMode:Text.WordWrap;color:redlineAppearance.color("#999",redlineAppearance.revision);Layout.fillWidth:true}
}
