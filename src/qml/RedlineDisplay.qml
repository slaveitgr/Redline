// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id: panel
 signal openGames()
 property int selected: 0
 property var monitor: displayBackend.monitors.length ? displayBackend.monitors[Math.min(selected,displayBackend.monitors.length-1)] : ({})
 property string modeId: ""
 property real scaleValue: 1
 property int colorValue: 0
 property var modes: monitor.modes || []
 property var mode: modes.find(function(m){return m.id===modeId}) || ({scales:[]})
 property bool editable: displayBackend.supported && Boolean(monitor.active) && !displayBackend.busy
 property var fixedModes: modes.filter(function(m){return !m.variable})
 property var labels: fixedModes.map(function(m){return m.width+" × "+m.height+" · "+m.hz.toFixed(2)+" Hz"})
 property var scales: (mode.scales || []).map(function(s){return (s*100).toFixed(0)+"%"})
 property bool variable: Boolean(mode.variable)
 property var counterpart: modes.find(function(m){return m.width===mode.width && m.height===mode.height && Math.abs(m.hz-mode.hz)<0.01 && Boolean(m.variable)!==variable})
 property var colorNames: (monitor.colors || []).map(function(c){return c===0?"Standard SDR":c===1?"HDR (BT.2100)":c===2?"Native SDR":"Color mode "+c})
 function reset(){modeId=monitor.mode || "";scaleValue=monitor.scale || 1;colorValue=monitor.color || 0}
 onMonitorChanged:reset()
 Component.onCompleted:reset()
 spacing:16
 RowLayout {
  Layout.fillWidth:true;Layout.minimumWidth:0
  Label{text:"Global Display";font.pixelSize:21;color:redlineAppearance.color("#eee",redlineAppearance.revision);Layout.fillWidth:true}
  ComboBox{visible:displayBackend.monitors.length>1;model:displayBackend.monitors.map(function(m){return m.name+" · "+m.connector});onActivated:{panel.selected=currentIndex;panel.reset()}}
  RedlineButton{text:"Refresh";enabled:!displayBackend.busy;onClicked:displayBackend.refresh()}
  RedlineButton{text:"Arrange Displays ↗";enabled:nativeDashboard.desktopSettingsAvailable();onClicked:nativeDashboard.openDesktopSettings("display")}
 }
 Label{text:(panel.monitor.name || "Desktop display")+" · "+(panel.monitor.connector || "GNOME controls unavailable");color:redlineAppearance.color("#aaa",redlineAppearance.revision);Layout.fillWidth:true;wrapMode:Text.WordWrap}
 RowLayout {
  Layout.fillWidth:true;spacing:24
  ColumnLayout {
   Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:(panel.width-24)/2;Layout.alignment:Qt.AlignTop
   RedlineSettingsGroup {
    heading:"Display Options"
    RedlineSettingRow{title:"Resolution & Refresh Rate";description:"Modes reported by the connected display";kind:"choice";choices:panel.labels;currentValue:panel.mode.width?panel.mode.width+" × "+panel.mode.height+" · "+panel.mode.hz.toFixed(2)+" Hz":"";supported:panel.editable;onRequested:function(value){var m=panel.fixedModes[panel.labels.indexOf(value)];panel.modeId=m.id;if(m.scales.indexOf(panel.scaleValue)<0)panel.scaleValue=m.scales[0]}}
    RedlineSettingRow{title:"Desktop Scaling";description:"Desktop interface size; separate from game rendering";kind:"choice";choices:panel.scales;currentValue:(panel.scaleValue*100).toFixed(0)+"%";supported:panel.editable;onRequested:function(value){panel.scaleValue=panel.mode.scales[panel.scales.indexOf(value)]}}
    RedlineSettingRow{title:"Adaptive Sync";description:"Variable refresh mode reported by GNOME";kind:"switch";currentValue:panel.variable;supported:panel.editable && Boolean(panel.counterpart);reason:panel.counterpart?"":"No matching fixed/variable refresh modes are exposed by the desktop.";onRequested:{panel.modeId=panel.counterpart.id}}
    RedlineSettingRow{title:"Display Color Mode";description:"Only color modes exposed by the compositor";kind:"choice";choices:panel.colorNames;currentValue:panel.colorNames[(panel.monitor.colors || []).indexOf(panel.colorValue)] || "Not reported";supported:panel.editable && panel.colorNames.length>1;onRequested:function(value){panel.colorValue=panel.monitor.colors[panel.colorNames.indexOf(value)]}}
   }
   RowLayout {
    RedlineButton{text:displayBackend.busy?"Checking…":"Apply Changes";enabled:panel.editable && (panel.modeId!==panel.monitor.mode || Math.abs(panel.scaleValue-panel.monitor.scale)>0.00001 || panel.colorValue!==panel.monitor.color);onClicked:displayBackend.apply(panel.monitor.connector,panel.modeId,panel.scaleValue,panel.colorValue)}
    RedlineButton{text:"Reset Selection";enabled:!displayBackend.busy;onClicked:panel.reset()}
   }
   Label{text:displayBackend.message || "After Apply, confirm in GNOME’s Keep Changes dialog. Unconfirmed changes revert automatically.";wrapMode:Text.WordWrap;Layout.fillWidth:true;color:redlineAppearance.color("#aaa",redlineAppearance.revision);font.pixelSize:12}
  }
  ColumnLayout {
   Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:(panel.width-24)/2;Layout.alignment:Qt.AlignTop
   RedlineSettingsGroup {
    heading:"Color & Desktop Tools"
    RedlineSettingRow{title:"Color Profiles";description:"Manage ICC profiles for this display";kind:"action";actionText:"Open ↗";supported:nativeDashboard.desktopSettingsAvailable();onRequested:nativeDashboard.openDesktopSettings("color")}
    RedlineSettingRow{title:"Desktop Display Settings";description:"Arrange, mirror, rotate or enable connected displays";kind:"action";actionText:"Open ↗";supported:nativeDashboard.desktopSettingsAvailable();onRequested:nativeDashboard.openDesktopSettings("display")}
   }
   RedlineSettingsGroup {
    heading:"Game Rendering & Scaling"
    RedlineSettingRow{title:"Virtual Super Resolution";kind:"action";actionText:"Configure ›";description:"Linux per-game supersampling: render above the output resolution using Gamescope.";onRequested:panel.openGames()}
    RedlineSettingRow{title:"GPU Scaling";kind:"action";actionText:"Configure ›";description:"Gamescope render and output resolution per game; separate from desktop scaling.";onRequested:panel.openGames()}
    RedlineSettingRow{title:"Scaling Mode";kind:"action";actionText:"Configure ›";description:"Choose fit, fill or stretch in game launch controls.";onRequested:panel.openGames()}
    RedlineSettingRow{title:"Integer Scaling";kind:"action";actionText:"Configure ›";description:"Choose integer scaling and nearest filtering in game launch controls.";onRequested:panel.openGames()}
    RedlineSettingRow{title:"Custom Color Adjustments";currentValue:"Not exposed by this backend";description:"Arbitrary saturation and gamma are not connected. Use supported color modes or system color profiles."}
   }
  }
 }
}
