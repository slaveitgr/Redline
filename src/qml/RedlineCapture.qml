// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id:page
 property string subpage:"Record"
 property var store
 property bool systemAudio:{var r=store.revision;return store.read("rec.systemAudio",false)}
 property bool microphone:{var r=store.revision;return store.read("rec.microphone",false)}
 property string codec:{var r=store.revision;var saved=store.read("rec.codec","vp8");return codecIds.indexOf(saved)>=0?saved:(codecIds.length?codecIds[0]:"vp8")}
 property int bitrate:{var r=store.revision;return Number(store.read("rec.bitrate",8))}
 property string resolution:{var r=store.revision;return store.read("rec.resolution","native")}
 property var codecLabels:captureBackend.codecs.map(function(c){return c.label})
 property var codecIds:captureBackend.codecs.map(function(c){return c.id})
 property int fps:{var r=store.revision;return parseInt(store.read("rec.fps","30 fps"))===60?60:30}
 function toggleRecording(){if(captureBackend.active)captureBackend.stop();else captureBackend.start({systemAudio:page.systemAudio,microphone:page.microphone,fps:page.fps,codec:page.codec,bitrate:page.bitrate,resolution:page.resolution})}
 function tr(s){return redlineAppearance.text(s,redlineAppearance.revision)}
 function shade(s){return redlineAppearance.color(s,redlineAppearance.revision)}
 ColumnLayout {
  anchors.fill:parent;anchors.margins:18;spacing:14
  RowLayout {Layout.fillWidth:true
   Label {text:page.tr(page.subpage==="Media"?"Media":page.subpage==="Settings"?"Recording Settings":"Record");font.pixelSize:22;color:page.shade("#eee");Layout.fillWidth:true}
   RedlineButton {text:"Refresh";visible:page.subpage==="Media";onClicked:captureBackend.refreshMedia()}
   RedlineButton {text:"Take a Screenshot";enabled:!captureBackend.screenshotBusy && !redlineReadOnly;onClicked:captureBackend.takeScreenshot()}
   RedlineButton {text:"Open recordings folder";onClicked:captureBackend.openFolder()}
  }
  Label {text:page.tr("Local recording through the Linux screen-sharing portal. Streaming, replay and scene editing are not connected yet.");wrapMode:Text.WordWrap;color:page.shade("#999");Layout.fillWidth:true}
  ColumnLayout {
   visible:page.subpage==="Settings";Layout.fillWidth:true;Layout.fillHeight:true;spacing:12
   RedlineSettingRow {title:"Recording FPS";kind:"choice";choices:["30","60"];currentValue:String(page.fps);supported:!captureBackend.active;onRequested:value=>page.store.write("rec.fps",value+" fps")}
   RedlineSettingRow {title:"System audio (experimental)";kind:"switch";currentValue:page.systemAudio;supported:captureBackend.audioSupported && !captureBackend.active;onRequested:value=>page.store.write("rec.systemAudio",value)}
   RedlineSettingRow {title:"Microphone";kind:"switch";currentValue:page.microphone;supported:captureBackend.audioSupported && !captureBackend.active;description:"Record the default microphone. Mixed with system audio when both are enabled.";onRequested:value=>page.store.write("rec.microphone",value)}
   RedlineSettingRow {title:"Video Encoding Type";kind:"choice";choices:page.codecLabels;currentValue:page.codecLabels[page.codecIds.indexOf(page.codec)] || "Select available encoder";supported:!captureBackend.active && page.codecLabels.length>0;description:"Software encoders installed on this system";onRequested:value=>page.store.write("rec.codec",page.codecIds[page.codecLabels.indexOf(value)])}
   RedlineSettingRow {title:"Recording Resolution";kind:"choice";choices:["native","720p","1080p"];currentValue:page.resolution;supported:!captureBackend.active;description:"Preserves aspect ratio with borders where required";onRequested:value=>page.store.write("rec.resolution",value)}
   RedlineSettingRow {title:"Video Bit Rate (Mb/s)";kind:"choice";choices:["2","4","8","12","16","24","32","50","100"];currentValue:String(page.bitrate);supported:!captureBackend.active;onRequested:value=>page.store.write("rec.bitrate",Number(value))}
   Item {Layout.fillHeight:true}
  }
  RowLayout {
   visible:page.subpage==="Record";Layout.fillWidth:true;Layout.fillHeight:true;spacing:14
   Rectangle {
    Layout.preferredWidth:270;Layout.fillHeight:true;color:page.shade("#252528")
    ColumnLayout {anchors.fill:parent;anchors.margins:14;spacing:16
     Label {text:page.tr("Controls");color:page.shade("#ddd");font.pixelSize:16}
     Label {text:page.tr("Select a monitor or window using the system screen-sharing dialog.");wrapMode:Text.WordWrap;color:page.shade("#aaa");Layout.fillWidth:true}
     RedlineSettingRow {title:"Recording FPS";kind:"choice";choices:["30","60"];currentValue:String(page.fps);supported:!captureBackend.active;onRequested:value=>page.store.write("rec.fps",value+" fps")}
     CheckBox {text:page.tr("System audio (experimental)");checked:page.systemAudio;enabled:captureBackend.audioSupported && !captureBackend.active;onToggled:page.store.write("rec.systemAudio",checked)}
     CheckBox {text:page.tr("Microphone");checked:page.microphone;enabled:captureBackend.audioSupported && !captureBackend.active;onToggled:page.store.write("rec.microphone",checked)}
     RedlineButton {text:captureBackend.active?"Stop recording":"Start recording";accent:true;Layout.fillWidth:true;enabled:captureBackend.active || captureBackend.supported;onClicked:page.toggleRecording()}
     Label {visible:redlineReadOnly;text:page.tr("Screen recording is disabled in UI preview. Open normal Redline.");wrapMode:Text.WordWrap;color:page.shade("#999");Layout.fillWidth:true}
     Label {text:page.tr(captureBackend.supported?((page.codecLabels[page.codecIds.indexOf(page.codec)] || "Select available encoder")+" · "+page.resolution+" · "+page.bitrate+" Mb/s"):"Capture dependencies are unavailable.");wrapMode:Text.WordWrap;color:page.shade("#999");Layout.fillWidth:true}
     Item {Layout.fillHeight:true}
    }
   }
   Rectangle {
    Layout.fillWidth:true;Layout.fillHeight:true;color:page.shade("#17171b")
    ColumnLayout {anchors.centerIn:parent;width:parent.width-60;spacing:20
     Label {text:captureBackend.state==="recording"?"●":"▷";color:captureBackend.state==="recording"?"#dd0031":page.shade("#777");font.pixelSize:54;Layout.alignment:Qt.AlignHCenter}
     Label {text:page.tr(captureBackend.state==="recording"?"Recording in progress.":captureBackend.state==="selecting"?"Choose a screen or window in the system dialog.":captureBackend.state==="stopping"?"Saving recording…":"Ready to record");wrapMode:Text.WordWrap;color:page.shade("#ddd");Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter;font.pixelSize:18}
     Label {text:Math.floor(captureBackend.seconds/60).toString().padStart(2,"0")+":"+(captureBackend.seconds%60).toString().padStart(2,"0");font.pixelSize:32;color:page.shade("#ddd");Layout.alignment:Qt.AlignHCenter}
     Label {text:page.tr("The selected screen is recorded directly. An in-app live preview is not implemented.");wrapMode:Text.WordWrap;color:page.shade("#999");Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter}
    }
   }
  }
  ListView {
   id:mediaList;visible:page.subpage==="Media";Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:8;model:captureBackend.media
   ScrollBar.vertical:ScrollBar{}
   delegate:Rectangle {
    required property var modelData;width:mediaList.width;implicitHeight:76;color:page.shade("#252528")
    RowLayout {anchors.fill:parent;anchors.margins:14
     ColumnLayout {Layout.fillWidth:true;Label{text:modelData.name;color:page.shade("#ddd");elide:Text.ElideRight;Layout.fillWidth:true}Label{text:modelData.modified+" · "+modelData.size;color:page.shade("#999");font.pixelSize:11}}
     RedlineButton {text:"Open";onClicked:captureBackend.openMedia(modelData.path)}
    }
   }
   Label {visible:mediaList.count===0;anchors.centerIn:parent;text:page.tr("No recordings or screenshots yet");color:page.shade("#999")}
  }
  Label {text:page.tr(captureBackend.message);visible:text.length>0;wrapMode:Text.WordWrap;color:page.shade("#aaa");Layout.fillWidth:true}
 }
}
