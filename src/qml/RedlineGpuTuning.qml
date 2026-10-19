// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:panel
 property var patch:({})
 property string editedDevice:""
 property var power:redlineGpu.stats.power || ({})
 property var fan:redlineGpu.stats.fan || ({})
 property bool canPower:power.cap_min!==undefined && power.cap_max!==undefined
 property bool canFan:fan.speed_max!==undefined && fan.pwm_max!==undefined
 implicitHeight:childrenRect.height
 spacing:8
 function tr(s){return redlineAppearance.text(s,redlineAppearance.revision)}
 function shade(s){return redlineAppearance.color(s,redlineAppearance.revision)}
 function edit(key,value){var next=Object.assign({},patch);next[key]=value;patch=next}
 Rectangle {
  Layout.fillWidth:true;Layout.preferredHeight:44;color:panel.shade("#18181b")
  RowLayout {anchors.fill:parent;anchors.margins:10
   Label {text:"GPU · Redline Engine";font.bold:true;color:panel.shade("#eee")}
   ComboBox {Layout.fillWidth:true;model:redlineGpu.devices;textRole:"name";onActivated:redlineGpu.selectDevice(redlineGpu.devices[currentIndex].id)}
   Label {text:panel.tr(redlineGpu.writable?"Hardware control":redlineGpu.ready?"Read-only preview":"Connecting…");color:panel.shade("#aaa")}
  }
 }
 Label {text:redlineGpu.error;visible:text.length>0;wrapMode:Text.WordWrap;Layout.fillWidth:true;color:"#ed003b"}
 RowLayout {
  Layout.fillWidth:true;spacing:12
  Repeater {
   model:[{label:"GPU clock",value:(redlineGpu.stats.clockspeed || {}).gpu_clockspeed,unit:" MHz"},{label:"GPU voltage",value:(redlineGpu.stats.voltage || {}).gpu,unit:" mV"},{label:"VRAM used",value:(redlineGpu.stats.vram || {}).used,unit:" MiB",scale:1048576},{label:"Power",value:panel.power.current,unit:" W"}]
   Rectangle {required property var modelData;Layout.fillWidth:true;Layout.preferredWidth:1;implicitHeight:76;color:panel.shade("#252528")
    Column {anchors.fill:parent;anchors.margins:12;spacing:8
     Label{text:panel.tr(modelData.label);color:panel.shade("#999");font.pixelSize:11}
     Label{text:modelData.value===undefined?"N/A":(Number(modelData.value)/(modelData.scale || 1)).toFixed(modelData.scale?0:1)+modelData.unit;color:panel.shade("#eee");font.pixelSize:18}
    }
   }
  }
 }
 RedlineSettingRow {
  title:"Performance mode";kind:"choice";choices:["auto","low","high"];currentValue:panel.patch.performance_level || redlineGpu.config.performance_level || redlineGpu.stats.performance_level || "auto"
  supported:redlineGpu.writable && redlineGpu.stats.performance_level!==undefined && !redlineGpu.pendingSeconds
  onRequested:value=>panel.edit("performance_level",value)
 }
 Rectangle {
  Layout.fillWidth:true;implicitHeight:68;color:panel.shade("#252528")
  RowLayout {anchors.fill:parent;anchors.margins:12
   Label {text:panel.tr("Power limit (W)");color:panel.shade("#ddd");Layout.fillWidth:true}
   Label {visible:!panel.canPower;text:panel.tr("Not exposed by this GPU");color:panel.shade("#999")}
   SpinBox {visible:panel.canPower;enabled:redlineGpu.writable;from:Math.ceil(panel.power.cap_min || 0);to:Math.floor(panel.power.cap_max || 0);value:Math.round(panel.patch.power_cap || redlineGpu.config.power_cap || panel.power.cap_current || 0);onValueModified:panel.edit("power_cap",value)}
  }
 }
 Rectangle {
  Layout.fillWidth:true;implicitHeight:68;color:panel.shade("#252528")
  RowLayout {anchors.fill:parent;anchors.margins:12
   Label {text:panel.tr("Fan control");color:panel.shade("#ddd");Layout.fillWidth:true}
   Label {visible:!panel.canFan;text:panel.tr("Not exposed by this GPU");color:panel.shade("#999")}
   ComboBox {visible:panel.canFan;enabled:redlineGpu.writable;model:["Automatic","Fixed 70%","Default curve"];onActivated:{if(currentIndex===0){panel.edit("fan_control_enabled",false)}else{panel.edit("fan_control_enabled",true);panel.edit("fan_control_settings",{mode:currentIndex===1?"static":"curve",static_speed:0.7,temperature_key:"edge",interval_ms:500,curve:{"40":0.3,"50":0.4,"60":0.55,"70":0.75,"80":1.0},spindown_delay_ms:1000,change_threshold:2})}}}
  }
 }
 RedlineSettingRow {title:"Clocks / Voltage";currentValue:redlineGpu.clocks.table?"Clocks table detected":"Not exposed by this GPU";description:"Only driver-exposed controls can be applied."}
 RedlineSettingRow {title:"Throttling";currentValue:Object.keys(redlineGpu.stats.throttle_info || {}).map(function(k){return (redlineGpu.stats.throttle_info[k] || []).join(", ")}).join(" · ") || "None reported"}
 RowLayout {
  Layout.fillWidth:true
  Label {text:panel.tr("GPU controls and live sensors");color:panel.shade("#888");font.pixelSize:11;Layout.fillWidth:true}
  RedlineButton {text:"Discard";enabled:Object.keys(panel.patch).length>0;onClicked:{panel.patch=({});redlineGpu.refresh()}}
  RedlineButton {text:"Apply GPU changes";accent:true;enabled:redlineGpu.writable && !redlineGpu.pendingSeconds && Object.keys(panel.patch).length>0;onClicked:{redlineGpu.apply(panel.patch);panel.patch=({})}}
 }
 Dialog {
  id:confirmation;parent:Overlay.overlay;anchors.centerIn:parent;modal:true;width:460;closePolicy:Popup.NoAutoClose;title:panel.tr("Confirm GPU settings")
  Label {width:parent.width;wrapMode:Text.WordWrap;text:panel.tr("Keep these settings? Automatic rollback in")+" "+redlineGpu.pendingSeconds+" s";color:panel.shade("#ddd")}
  footer:RowLayout {RedlineButton{text:"Revert";onClicked:redlineGpu.confirm(false)}RedlineButton{text:"Keep settings";accent:true;onClicked:redlineGpu.confirm(true)}}
 }
 Connections {target:redlineGpu;function onChanged(){if(panel.editedDevice!==redlineGpu.deviceId){panel.patch=({});panel.editedDevice=redlineGpu.deviceId}if(redlineGpu.pendingSeconds>0 && !confirmation.opened)confirmation.open();if(!redlineGpu.pendingSeconds)confirmation.close()}}
}
