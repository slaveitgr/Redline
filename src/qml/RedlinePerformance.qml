// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id:performance
 property bool logError:false
 property var store
 property bool overlayMode:{var r=store.revision;return store.read("perf.metrics.mode","Tracking")==="Overlay"}
 function tr(s){return redlineAppearance.text(s,redlineAppearance.revision)}
 function shade(s){return redlineAppearance.color(s,redlineAppearance.revision)}
 function shown(key){var r=store.revision;return store.read("perf.visible."+key,true)}
 property var overlayFields:[{key:"fps",label:"FPS"},{key:"frametime",label:"Frame Time"},{key:"cpu_stats",label:"CPU utilization"},{key:"gpu_stats",label:"GPU utilization"},{key:"cpu_temp",label:"CPU temperature"},{key:"gpu_temp",label:"GPU temperature"},{key:"ram",label:"System memory"},{key:"vram",label:"VRAM used"},{key:"gpu_power",label:"GPU sensor power"},{key:"gpu_core_clock",label:"GPU clock"},{key:"gpu_fan",label:"Fan speed"},{key:"frame_timing",label:"Frame-time graph"}]
 function overlayMetrics(){var r=store.revision;var result={};for(var i=0;i<overlayFields.length;i++)result[overlayFields[i].key]=store.read("perf.overlay.metric."+overlayFields[i].key,i<8);return result}
 function setOverlayProfile(name){for(var i=0;i<overlayFields.length;i++){var key=overlayFields[i].key;store.write("perf.overlay.metric."+key,name==="Detailed" || (name==="Balanced" && i<8) || (name==="Compact" && (key==="fps" || key==="gpu_stats" || key==="cpu_stats")))}}
 function overlayProfile(){var values=overlayMetrics();var names=["Compact","Balanced","Detailed"];for(var n=0;n<names.length;n++){var matches=true;for(var i=0;i<overlayFields.length;i++){var key=overlayFields[i].key;var expected=names[n]==="Detailed" || (names[n]==="Balanced" && i<8) || (names[n]==="Compact" && (key==="fps" || key==="gpu_stats" || key==="cpu_stats"));if(values[key]!==expected)matches=false}if(matches)return names[n]}return "Custom"}
 signal openTuning()
 signal openGaming()
 RowLayout {
  anchors.fill:parent;anchors.margins:18;spacing:14
  ScrollView {
   id:metricsScroll;Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth;clip:true
   RowLayout {
    width:metricsScroll.availableWidth;spacing:14
    ColumnLayout {
     Layout.fillWidth:true;Layout.preferredWidth:1;Layout.alignment:Qt.AlignTop;spacing:14
     ColumnLayout {
      visible:performance.shown("fps");Layout.fillWidth:true;spacing:1
      Rectangle {Layout.fillWidth:true;height:32;color:performance.shade("#29292c");Label{anchors.fill:parent;anchors.leftMargin:12;verticalAlignment:Text.AlignVCenter;text:"FPS";color:performance.shade("#ddd");font.pixelSize:11}}
      Repeater {model:[{label:"Framerate",key:"fps"},{label:"Frame Time",key:"frameTime"},{label:"99% FPS",key:"fps99"}];RedlineMetric{store:performance.store;required property var modelData;Layout.fillWidth:true;title:modelData.label;metricKey:modelData.key}}
      Label {text:performance.tr("No game telemetry connected");font.pixelSize:10;color:performance.shade("#888");Layout.margins:8}
     }
     ColumnLayout {
      visible:performance.shown("gpu");Layout.fillWidth:true;spacing:1
      Rectangle {Layout.fillWidth:true;height:32;color:performance.shade("#29292c");Label{anchors.fill:parent;anchors.leftMargin:12;verticalAlignment:Text.AlignVCenter;text:"GPU · "+(nativeDashboard.systemInfo.driver || "AMD");color:performance.shade("#ddd");font.pixelSize:11}}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"Utilization";metricKey:"gpu"}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"GPU sensor power";metricKey:"power";scaleMaximum:100}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"GPU temperature";metricKey:"temperature";scaleMaximum:110}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"Clock speed";metricKey:"clock";scaleMaximum:3000}
     }
    }
    ColumnLayout {
     Layout.fillWidth:true;Layout.preferredWidth:1;Layout.alignment:Qt.AlignTop;spacing:14
     ColumnLayout {
      visible:performance.shown("cpu");Layout.fillWidth:true;spacing:1
      Rectangle {Layout.fillWidth:true;height:32;color:performance.shade("#29292c");Label{anchors.fill:parent;anchors.leftMargin:12;anchors.rightMargin:8;verticalAlignment:Text.AlignVCenter;text:"CPU · "+nativeDashboard.systemInfo.cpuName;elide:Text.ElideRight;color:performance.shade("#ddd");font.pixelSize:11}}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"Utilization";metricKey:"cpu";traceColor:"#e87921"}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"CPU temperature";metricKey:"cpuTemperature";scaleMaximum:110;traceColor:"#e87921"}
     }
     ColumnLayout {
      visible:performance.shown("memory");Layout.fillWidth:true;spacing:1
      Rectangle {Layout.fillWidth:true;height:32;color:performance.shade("#29292c");Label{anchors.fill:parent;anchors.leftMargin:12;verticalAlignment:Text.AlignVCenter;text:performance.tr("SYSTEM MEMORY");color:performance.shade("#ddd");font.pixelSize:11}}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"RAM used / total";metricKey:"memory";scaleMaximum:parseFloat(nativeDashboard.systemInfo.memoryTotal)||32;traceColor:"#e87921"}
     }
     ColumnLayout {
      visible:performance.shown("gpu");Layout.fillWidth:true;spacing:1
      Rectangle {Layout.fillWidth:true;height:32;color:performance.shade("#29292c");Label{anchors.fill:parent;anchors.leftMargin:12;verticalAlignment:Text.AlignVCenter;text:performance.tr("GPU Memory & Cooling");color:performance.shade("#ddd");font.pixelSize:11}}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"VRAM used";metricKey:"vramUsed";scaleMaximum:parseFloat(nativeDashboard.metrics.vramTotal)||4096}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"Memory clock";metricKey:"memoryClock";scaleMaximum:3000}
      RedlineMetric {store:performance.store;Layout.fillWidth:true;title:"Fan speed";metricKey:"fan";scaleMaximum:6000}
     }
     Label {visible:!performance.shown("cpu") && !performance.shown("memory");text:performance.tr("Select metrics in Tracking");color:performance.shade("#999")}
    }
   }
  }
  Rectangle {
   Layout.preferredWidth:290;Layout.fillHeight:true;color:performance.shade("#252528")
   ColumnLayout {
    anchors.fill:parent;spacing:1
    RowLayout {
     Layout.fillWidth:true;spacing:0
     Repeater {model:["Tracking","Overlay"];TabButton {id:modeTab;required property string modelData;background:Rectangle{color:"transparent";Rectangle{anchors.bottom:parent.bottom;width:parent.width;height:3;color:"#ed003b";visible:modeTab.checked}}text:performance.tr(modelData);Layout.fillWidth:true;checked:performance.overlayMode===(modelData==="Overlay");onClicked:store.write("perf.metrics.mode",modelData)}}
    }
    ScrollView {
     id:sidebar;Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth;clip:true
     ColumnLayout {
      width:sidebar.availableWidth;spacing:12
      ColumnLayout {
       visible:!performance.overlayMode;Layout.fillWidth:true;Layout.margins:12;spacing:14
       RedlineButton {text:nativeDashboard.logging?"Stop Logging":"Start Logging";accent:true;Layout.fillWidth:true;onClicked:{if(nativeDashboard.logging)nativeDashboard.stopLogging();else if(!nativeDashboard.startLogging())logError=true}}
       Label {text:performance.tr(performance.logError?"Could not create log file.":nativeDashboard.logging?"Recording hardware metrics to CSV":"Hardware metrics · CSV export");color:performance.shade("#999");font.pixelSize:11;wrapMode:Text.WordWrap;Layout.fillWidth:true}
       RedlineButton {text:"Open logs folder";visible:nativeDashboard.loggingPath.length>0;Layout.fillWidth:true;onClicked:nativeDashboard.openLogs()}
       RedlineSettingRow {title:"Sampling interval";kind:"choice";choices:["0.25","0.5","1","2","5"];description:"Seconds between hardware measurements";currentValue:{var r=store.revision;return String(store.read("perf.interval",1))} onRequested:value=>store.write("perf.interval",Number(value))}
       RedlineSettingRow {title:"Graphing duration";kind:"choice";choices:["10","30","60","120"];description:"Seconds shown in live graphs";currentValue:{var r=store.revision;return String(store.read("perf.duration",60))} onRequested:value=>store.write("perf.duration",Number(value))}
       Label {text:nativeDashboard.historyDurationSeconds+" s · "+nativeDashboard.history.length+" samples";color:performance.shade("#999");font.pixelSize:11}
       Label {text:performance.tr("Visible metrics");color:performance.shade("#ddd");font.pixelSize:13}
       Repeater {
        model:[{key:"fps",label:"FPS"},{key:"gpu",label:"GPU"},{key:"cpu",label:"CPU"},{key:"memory",label:"System memory"}]
        CheckBox {required property var modelData;text:performance.tr(modelData.label);checked:performance.shown(modelData.key);onToggled:store.write("perf.visible."+modelData.key,checked)}
       }
       RedlineButton {text:"Graphics tuning ›";Layout.fillWidth:true;onClicked:performance.openTuning()}
      }
      ColumnLayout {
       visible:performance.overlayMode;Layout.fillWidth:true;Layout.margins:12;spacing:1
       RedlineSettingRow {title:"Enable Metrics Overlay";kind:"switch";showStateLabel:false;supported:gamingTools.available().overlay || gamingTools.available("snap").overlay;currentValue:{var r=store.revision;return store.read("perf.overlay",true)} onRequested:value=>store.write("perf.overlay",value)}
       RedlineSettingRow {title:"Overlay profile";kind:"choice";choices:["Compact","Balanced","Detailed","Custom"];currentValue:performance.overlayProfile();onRequested:value=>{if(value!=="Custom")performance.setOverlayProfile(value)}}
       RedlineSettingRow {title:"Horizontal layout";kind:"switch";showStateLabel:false;currentValue:{var r=store.revision;return store.read("perf.overlay.horizontal",false)} onRequested:value=>store.write("perf.overlay.horizontal",value)}
       RedlineSettingRow {title:"Overlay hotkey";kind:"choice";choices:["Shift+F12","Shift+F11","Ctrl+F12"];currentValue:{var r=store.revision;return store.read("perf.overlay.hotkey","Shift_R+F12").replace("Shift_R","Shift").replace("Control_R","Ctrl")} onRequested:value=>store.write("perf.overlay.hotkey",value.replace("Shift+","Shift_R+").replace("Ctrl+","Control_R+"))}
       RedlineSettingRow {title:"FPS limit";description:"All games using this MangoHud configuration. 0 means unlimited.";kind:"choice";choices:["0","30","40","60","90","120","144","165","240"];currentValue:{var r=store.revision;return String(store.read("perf.overlay.fpsLimit",0))} onRequested:value=>store.write("perf.overlay.fpsLimit",Number(value))}
       RedlineSettingRow {title:"Location";kind:"choice";choices:["top-left","top-right","bottom-left","bottom-right"];currentValue:{var r=store.revision;return store.read("perf.overlay.position","top-right")} onRequested:value=>store.write("perf.overlay.position",value)}
       Label {text:performance.tr("Font size");color:performance.shade("#ddd");Layout.topMargin:12}
       Slider {Layout.fillWidth:true;from:12;to:40;stepSize:1;value:{var r=store.revision;return store.read("perf.overlay.font",20)} onMoved:store.write("perf.overlay.font",Math.round(value))}
       Label {text:performance.tr("Background opacity");color:performance.shade("#ddd")}
       Slider {Layout.fillWidth:true;from:0;to:100;stepSize:5;value:{var r=store.revision;return store.read("perf.overlay.opacity",50)} onMoved:store.write("perf.overlay.opacity",Math.round(value))}
       Label {text:performance.tr("Overlay metrics");color:performance.shade("#ddd");Layout.topMargin:14}
       Repeater {model:performance.overlayFields;CheckBox {required property var modelData;text:performance.tr(modelData.label);checked:performance.overlayMetrics()[modelData.key];onToggled:store.write("perf.overlay.metric."+modelData.key,checked)}}
       Label {text:performance.tr("MangoHud overlay is available for connected game launches. Open Gaming, select a game and Apply to Steam. Restart the game after changing these settings.");color:performance.shade("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.topMargin:12}
       RedlineButton {text:"Open Gaming";Layout.fillWidth:true;onClicked:performance.openGaming()}
       Label {text:performance.tr("GameMode status")+": "+gamingTools.gameModeStatus;color:performance.shade("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true}

      }
     }
    }
    Label {text:performance.tr("Live hardware sensors")+" · "+(nativeDashboard.samplingIntervalMs/1000)+" s";color:performance.shade("#999");font.pixelSize:10;Layout.margins:12}
   }
  }
 }
}
