// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id:page
 property var store
 property bool chat:false
 property string profile:{var r=store.revision;return store.read("stream.profile","High")}
 property string resolution:{var r=store.revision;return store.read("stream.resolution","1080p")}
 property int fps:{var r=store.revision;return Number(store.read("stream.fps",30))}
 property int bitrate:{var r=store.revision;return Number(store.read("stream.bitrate",6))}
 property int audioBitrate:{var r=store.revision;return Number(store.read("stream.audioBitrate",128))}
 property bool systemAudio:{var r=store.revision;return store.read("stream.audio",false)}
 property bool archive:{var r=store.revision;return store.read("stream.archive",false)}
 property bool microphone:{var r=store.revision;return store.read("stream.microphone",false)}
 function shade(c){return redlineAppearance.color(c,redlineAppearance.revision)}
 function preset(value){store.write("stream.profile",value);if(value==="Custom")return;var p=value==="Low"?["720p",30,3]:value==="Medium"?["720p",60,5]:value==="High"?["1080p",30,6]:["1080p",60,10];store.write("stream.resolution",p[0]);store.write("stream.fps",p[1]);store.write("stream.bitrate",p[2])}
 function verify(){var old=[store.read("stream.profile","High"),store.read("stream.resolution","1080p"),store.read("stream.fps",30),store.read("stream.bitrate",6)];preset("Low");var valid=store.read("stream.resolution","")==="720p" && Number(store.read("stream.bitrate",0))===3;store.write("stream.profile",old[0]);store.write("stream.resolution",old[1]);store.write("stream.fps",old[2]);store.write("stream.bitrate",old[3]);return valid && server.text.length===0 && streamKey.text.length===0}
 function goLive(){captureBackend.start({scene:page.store.captureScene(),stream:true,archive:page.archive,server:server.text.trim(),key:streamKey.text,codec:"h264",resolution:page.resolution,fps:page.fps,bitrate:page.bitrate,audioBitrate:page.audioBitrate,systemAudio:page.systemAudio,microphone:page.microphone});streamKey.clear()}
 ColumnLayout {
  anchors.fill:parent;anchors.margins:18;spacing:14
  Label {text:"Live Stream";font.pixelSize:22;color:page.shade("#eee")}
  RowLayout {
   Layout.fillWidth:true;Layout.fillHeight:true;spacing:16
   Rectangle {
    Layout.preferredWidth:340;Layout.fillHeight:true;color:page.shade("#252528")
    ColumnLayout {
     anchors.fill:parent;spacing:0
     RowLayout {Layout.fillWidth:true
      RedlineButton {text:"Controls";accent:!page.chat;Layout.fillWidth:true;onClicked:page.chat=false}
      RedlineButton {text:"Chat";accent:page.chat;Layout.fillWidth:true;onClicked:page.chat=true}
     }
     ScrollView {
      Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth;clip:true
      ColumnLayout {
       width:parent.width;spacing:12
       Label {visible:page.chat;text:"Chat requires a service account integration. Custom RTMP does not provide chat or viewer counts.";color:page.shade("#aaa");wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.margins:14}
       ColumnLayout {
        visible:!page.chat;Layout.fillWidth:true;Layout.margins:14;spacing:12
        Label {text:"Custom Stream";color:page.shade("#eee");font.pixelSize:16}
        Label {text:"Custom Stream URL";color:page.shade("#bbb")}
        TextField {id:server;placeholderText:"rtmps://server.example/live";Layout.fillWidth:true;enabled:!captureBackend.active;maximumLength:2048;inputMethodHints:Qt.ImhUrlCharactersOnly;selectByMouse:true}
        Label {text:"Custom Stream Key";color:page.shade("#bbb")}
        TextField {id:streamKey;placeholderText:"Session only";echoMode:TextInput.Password;Layout.fillWidth:true;enabled:!captureBackend.active;maximumLength:1024;inputMethodHints:Qt.ImhSensitiveData|Qt.ImhNoPredictiveText;selectByMouse:true}
        Label {text:"The key is used only for this session and is not saved. Choose the audience and title on your streaming service.";wrapMode:Text.WordWrap;Layout.fillWidth:true;color:page.shade("#999")}
        RedlineSettingRow {title:"Streaming Profile";kind:"choice";choices:["Low","Medium","High","Ultra","Custom"];currentValue:page.profile;supported:!captureBackend.active;onRequested:value=>page.preset(value)}
        RedlineSettingRow {title:"Resolution";kind:"choice";choices:["720p","1080p"];currentValue:page.resolution;supported:!captureBackend.active;onRequested:value=>{page.store.write("stream.profile","Custom");page.store.write("stream.resolution",value)}}
        RedlineSettingRow {title:"FPS";kind:"choice";choices:["30","60"];currentValue:String(page.fps);supported:!captureBackend.active;onRequested:value=>{page.store.write("stream.profile","Custom");page.store.write("stream.fps",Number(value))}}
        RedlineSettingRow {title:"Video Bit Rate (Mb/s)";kind:"choice";choices:["2","3","4","5","6","8","10","12","16","24"];currentValue:String(page.bitrate);supported:!captureBackend.active;onRequested:value=>{page.store.write("stream.profile","Custom");page.store.write("stream.bitrate",Number(value))}}
        RedlineSettingRow {title:"Audio Bit Rate (kb/s)";kind:"choice";choices:["96","128","160","192","256","320"];currentValue:String(page.audioBitrate);supported:!captureBackend.active;onRequested:value=>page.store.write("stream.audioBitrate",Number(value))}
        RedlineSettingRow {title:"Archive Stream";kind:"switch";currentValue:page.archive;supported:!captureBackend.active;description:"Save an MP4 copy in Media. Use Stop Streaming to finish the file.";onRequested:value=>page.store.write("stream.archive",value)}
        CheckBox {text:"System audio";checked:page.systemAudio;enabled:captureBackend.audioSupported && !captureBackend.active;onToggled:page.store.write("stream.audio",checked)}
        CheckBox {text:"Microphone";checked:page.microphone;enabled:captureBackend.audioSupported && !captureBackend.active;onToggled:page.store.write("stream.microphone",checked)}
        Label {text:"H.264 / AAC · software encoding";color:page.shade("#999")}
       }
      }
     }
     RedlineButton {Layout.fillWidth:true;Layout.margins:14;accent:true;text:captureBackend.active && captureBackend.streaming?"Stop Streaming":"Go Live";enabled:!redlineReadOnly && ((captureBackend.active && captureBackend.streaming) || (!captureBackend.active && captureBackend.streamingSupported && server.text.length>0 && streamKey.text.length>0));onClicked:{if(captureBackend.active)captureBackend.stop();else page.goLive()}}
    }
   }
   Rectangle {
    Layout.fillWidth:true;Layout.fillHeight:true;color:page.shade("#17171b")
    ColumnLayout {
     anchors.fill:parent;anchors.margins:18
     Label {text:"Stream Preview";font.pixelSize:16;color:page.shade("#ddd")}
     RedlineCapturePreview {visible:captureBackend.previewAvailable && captureBackend.streaming;Layout.fillWidth:true;Layout.fillHeight:true}
     Item {visible:!captureBackend.previewAvailable;Layout.fillHeight:true}
     Label {text:captureBackend.active && captureBackend.streaming?(captureBackend.state==="streaming"?"● SENDING":"CONNECTING / SELECTING SOURCE"):"OFFLINE";font.pixelSize:25;color:captureBackend.active && captureBackend.streaming?"#ed003b":page.shade("#999");Layout.alignment:Qt.AlignHCenter}
     Label {text:captureBackend.active && captureBackend.streaming?Math.floor(captureBackend.seconds/60).toString().padStart(2,"0")+":"+(captureBackend.seconds%60).toString().padStart(2,"0"):"";font.pixelSize:30;color:page.shade("#ddd");Layout.alignment:Qt.AlignHCenter}
     Label {text:"Select a screen or window in the system dialog after Go Live. Verify delivery and audience in your service dashboard.";color:page.shade("#999");wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;Layout.fillWidth:true}
     Label {text:"System audio";color:page.shade("#999")}
     ProgressBar {from:0;to:1;value:captureBackend.systemLevel;Layout.fillWidth:true}
     Label {text:"Microphone";color:page.shade("#999")}
     ProgressBar {from:0;to:1;value:captureBackend.microphoneLevel;Layout.fillWidth:true}
     Label {visible:!captureBackend.streamingSupported;text:"Install the H.264, AAC and RTMP GStreamer plugins to enable streaming.";color:"#dc9b63";wrapMode:Text.WordWrap;Layout.fillWidth:true}
     Label {visible:redlineReadOnly;text:"Streaming is disabled in Preview. Open normal Redline.";color:page.shade("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true}
     Item {visible:!captureBackend.previewAvailable;Layout.fillHeight:true}
     Label {text:captureBackend.message;color:page.shade("#bbb");wrapMode:Text.WordWrap;Layout.fillWidth:true}
    }
   }
  }
 }
}
