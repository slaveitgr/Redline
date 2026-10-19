// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:page
 property var store
 property string backend:{var revision=store.revision;var value=store.read("vr.backend","ALVR");return ["ALVR","WiVRn"].indexOf(value)>=0?value:"ALVR"}
 property bool alvrAvailable:Boolean(systemIntegration.vr.alvr_dashboard || systemIntegration.vr.alvr_launcher)
 property bool wivrnAvailable:Boolean(systemIntegration.vr["wivrn-dashboard"] || systemIntegration.vr.wivrnFlatpak)
 property bool selectedAvailable:backend==="ALVR"?alvrAvailable:wivrnAvailable
 function showInstaller(target){installDialog.target=target;installDialog.open()}
 function tr(s){return redlineAppearance.text(s,redlineAppearance.revision)}
 function shade(s){return redlineAppearance.color(s,redlineAppearance.revision)}
 spacing:18
 RowLayout {
  Layout.fillWidth:true
  Label {text:page.tr("VR Headset Devices");font.pixelSize:21;color:page.shade("#ddd");Layout.fillWidth:true}
  RedlineButton {text:"Refresh system";onClicked:systemIntegration.refresh()}
  RedlineButton {text:"How to Setup Your VR Headset";onClicked:systemIntegration.openReference(page.backend==="ALVR"?"alvr":"wivrn")}
  RedlineButton {text:"VR Settings";accent:true;enabled:page.selectedAvailable;onClicked:systemIntegration.launchVR(page.backend)}
 }
 Label {text:page.tr("ReLive VR-style workspace · Linux streaming through ALVR or WiVRn. AMD's Windows ReLive server is not running here.");color:page.shade("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true}
 RedlineSettingsGroup {
  heading:"VR software"
  Repeater {model:[{name:"ALVR",ready:page.alvrAvailable},{name:"WiVRn",ready:page.wivrnAvailable}]
   RowLayout {required property var modelData;Layout.fillWidth:true;Layout.margins:12
    Label {text:modelData.name;color:page.shade("#ddd");font.pixelSize:16;Layout.fillWidth:true}
    Label {text:page.tr(modelData.ready?"Installed":"Not installed");color:page.shade("#999")}
    RedlineButton {text:modelData.ready?"Open":"Install";accent:!modelData.ready;enabled:!vrInstaller.busy;onClicked:{if(modelData.ready)systemIntegration.launchVR(modelData.name);else{installDialog.target=modelData.name;installDialog.open()}}}
   }
  }
  ProgressBar {visible:vrInstaller.busy;Layout.fillWidth:true;indeterminate:vrInstaller.progress<0;from:0;to:100;value:vrInstaller.progress}
  Label {text:page.tr(vrInstaller.message);visible:text.length>0;color:page.shade("#aaa");wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.margins:12}
  RedlineButton {text:"Flatpak setup ↗";visible:!page.wivrnAvailable;onClicked:systemIntegration.openReference("flatpak")}
 }
 Dialog {
  id:installDialog;property string target:"ALVR";parent:Overlay.overlay;anchors.centerIn:parent;modal:true;width:540;title:page.tr("Install")+" "+target
  ColumnLayout {width:parent.width;spacing:12
   Label {text:page.tr(installDialog.target==="ALVR"?"Download the official ALVR launcher from GitHub into your Redline user data folder. The launcher will guide you through the remaining setup.":"Install WiVRn from your existing Flathub source. A system installation may ask for administrator approval. Missing Flatpak or Flathub requires the setup guide first.");wrapMode:Text.WordWrap;Layout.fillWidth:true;color:page.shade("#ddd")}
   Label {text:page.tr("This installs the PC software. You will still need the matching headset app and pairing setup.");wrapMode:Text.WordWrap;Layout.fillWidth:true;color:page.shade("#aaa")}
   Label {visible:redlineReadOnly;text:page.tr("Installation is disabled in UI preview. Open normal Redline.");wrapMode:Text.WordWrap;Layout.fillWidth:true;color:page.shade("#aaa")}
  }
  footer:Item {implicitHeight:64;RowLayout {anchors.fill:parent;anchors.margins:12;Item{Layout.fillWidth:true}RedlineButton{text:"Cancel";onClicked:installDialog.close()}RedlineButton{text:"Install";accent:true;enabled:!redlineReadOnly && !vrInstaller.busy;onClicked:{vrInstaller.install(installDialog.target);installDialog.close()}}}}
 }
 RedlineSettingsGroup {
  heading:"Integration"
  RedlineSettingRow {title:"Linux VR backend";kind:"choice";choices:["ALVR","WiVRn"];currentValue:page.backend;onRequested:value=>page.store.write("vr.backend",value)}
  RedlineSettingRow {title:"SteamVR";currentValue:nativeDashboard.systemInfo.steamVrInstalled?"SteamVR detected":"SteamVR was not detected";description:"ALVR uses SteamVR. WiVRn uses OpenXR; OpenVR games need a compatibility layer."}
  RedlineSettingRow {title:"ALVR dashboard";currentValue:page.alvrAvailable?"Detected":"Not installed or not detected"}
  RedlineSettingRow {title:"WiVRn dashboard";currentValue:page.wivrnAvailable?"Detected":"Not installed or not detected"}
 }
 Rectangle {
  Layout.fillWidth:true;implicitHeight:190;color:page.shade("#17171b");border.color:page.shade("#39393f")
  ColumnLayout {
   anchors.fill:parent;anchors.margins:24;spacing:14
   Label {text:page.tr("Choose your headset in the backend setup wizard");color:page.shade("#ddd");font.pixelSize:18;wrapMode:Text.WordWrap;Layout.fillWidth:true}
   Label {text:page.tr("Open its dashboard to pair a headset and configure bitrate, encoder, resolution and audio. Redline does not yet read headset connection or streaming state.");color:page.shade("#aaa");wrapMode:Text.WordWrap;Layout.fillWidth:true}
   RedlineButton {text:"Link a Device";enabled:page.selectedAvailable;accent:true;onClicked:systemIntegration.launchVR(page.backend)}
  }
 }
 RedlineSettingsGroup {
  heading:"VR Streaming"
  RedlineSettingRow {title:"Pairing / headset devices";currentValue:"Managed in backend dashboard"}
  RedlineSettingRow {title:"Bit Rate / Encoder / Protocol";currentValue:"Managed in backend dashboard";description:"Windows ReLive settings are not copied into an incompatible Linux backend."}
 }
 Label {visible:systemIntegration.message.length>0;text:page.tr(systemIntegration.message);color:page.shade("#ddd");wrapMode:Text.WordWrap;Layout.fillWidth:true}
}
