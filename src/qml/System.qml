// SPDX-License-Identifier: GPL-3.0-or-later
// Based on CoreCtrl System.qml, Copyright 2019 Juan Palacios.
// CoreCtrl's information provider is retained; Redline presents grouped settings.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CoreCtrl.UIComponents 1.0
Item {
 id: page
 property var store
 property string subpage: "System"
 property bool expandAll: false
 function expandDetails(){expandAll=true}
 function runPreferenceSmoke(){
  var keys=["sysTray","startOnSysTray","saveWindowGeometry","Ui/toastNotifications","Ui/animations"]
  var passed=nativeDashboard.systemInfo.cpuName!=="Unavailable" && nativeDashboard.systemInfo.kernel.length>0 && nativeDashboard.displays.length>0 && groups.length>0
  for(var i=0;i<keys.length;i++){var before=Boolean(settings.getValue(keys[i],keys[i]!=="startOnSysTray"));settings.setValue(keys[i],!before);passed=passed && Boolean(settings.getValue(keys[i],before))===!before;settings.setValue(keys[i],before)}
  return passed
 }
 property var groups: []
 property int preferencesRevision: 0
 property int displayIndex: 0
 property var screen: nativeDashboard.displays.length ? nativeDashboard.displays[Math.min(displayIndex,nativeDashboard.displays.length-1)] : ({})
 signal showAbout()
 signal information(string title,string message)
 signal preferenceSaved(string message)
 function showVRInstall(){snapshotDialog.close();vrPage.showInstaller("ALVR")}
 function showSnapshots(){snapshotDialog.showSnapshots()}
 function preference(key,fallback) {var rev=preferencesRevision;return settings.getValue(key,fallback)}
 function updatePreference(key,value) {settings.setValue(key,value);page.preferenceSaved("Preference saved")}
 function infoGroup(type) {for(var i=0;i<groups.length;i++)if(groups[i].name.toLowerCase().indexOf(type)>=0)return groups[i];return {name:"",rows:[]}}
 function infoValue(type,words,fallback) {var rows=infoGroup(type).rows;for(var i=0;i<rows.length;i++)for(var j=0;j<words.length;j++)if((rows[i].title.toLowerCase()===words[j] || rows[i].title.toLowerCase()===redlineAppearance.text(words[j].charAt(0).toUpperCase()+words[j].slice(1),redlineAppearance.revision).toLowerCase()))return rows[i].value;return fallback}
 function addInfo(name,values) {var rows=[];for(var i=0;i<values.length;i+=2)rows.push({title:String(values[i]),value:String(values[i+1])});groups=groups.concat([{name:String(name).replace(/\n/g," "),rows:rows}])}
 Connections {target:settings;function onSettingChanged(key,value){page.preferencesRevision++}}
 RedlineSnapshotDialog {id:snapshotDialog}
 SYSTEM_INFO {id:systemInfo;objectName:"SYSTEM_INFO";onAddSystemInfo:(componentName,info)=>page.addInfo(componentName,info)}
 ScrollView {
  id:settingsScroll
  anchors.fill:parent;clip:true;contentWidth:availableWidth
  GridLayout {
   width:settingsScroll.availableWidth;columns:2;uniformCellWidths:true;columnSpacing:26;rowSpacing:0
   // SYSTEM: software on the left, real hardware on the right.
   ColumnLayout {
    visible:page.subpage==="System";Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:(settingsScroll.availableWidth-98)/2;Layout.alignment:Qt.AlignTop;Layout.margins:18;spacing:12
    RedlineSettingsGroup {
     heading:"Redline — Linux Graphics Edition"
     Rectangle {
      Layout.fillWidth:true;implicitHeight:154;color:redlineAppearance.color("#252528", redlineAppearance.revision)
      ColumnLayout {
       anchors.fill:parent;anchors.margins:18;spacing:12
       RowLayout {
        Layout.fillWidth:true
        Column {Layout.fillWidth:true;spacing:9
         Label{text:redlineAppearance.text(("Software version"), redlineAppearance.revision);color:redlineAppearance.color("#99999f", redlineAppearance.revision);font.pixelSize:12}
         Label{text:redlineAppearance.text((appInfo.version), redlineAppearance.revision);color:redlineAppearance.color("#ededf0", redlineAppearance.revision);font.pixelSize:25}
        }
        Column {Layout.fillWidth:true;spacing:9
         Label{text:redlineAppearance.text(("Status"), redlineAppearance.revision);color:redlineAppearance.color("#99999f", redlineAppearance.revision);font.pixelSize:12}
         Label{text:redlineAppearance.text((redlineReadOnly?"Read-only preview":"Hardware control"), redlineAppearance.revision);color:redlineAppearance.color("#ededf0", redlineAppearance.revision);font.pixelSize:18}
        }
       }
       Label{text:redlineAppearance.text(("Driver: "+(nativeDashboard.systemInfo.driver || "Not reported")+"  ·  "+nativeDashboard.systemInfo.os), redlineAppearance.revision);color:redlineAppearance.color("#a0a0a8", redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true}
       RowLayout {
        Layout.fillWidth:true
        RedlineButton{text:"About Redline";Layout.fillWidth:true;onClicked:page.showAbout()}
        RedlineButton{text:"Copy system info";accent:true;Layout.fillWidth:true;onClicked:{systemInfo.copyToClipboard();page.preferenceSaved("System information copied")}}
       }
      }
     }
    }
    RedlineDriverStatus {Layout.fillWidth:true}
    RedlineSettingsGroup {
     heading:"Settings & support"
     RedlineSettingRow{title:redlineAppearance.text(("Snap Settings"), redlineAppearance.revision);description:"Import or export application settings";kind:"action";actionText:"Import / Export";onRequested:snapshotDialog.showSnapshots()}
     RedlineSettingRow{title:redlineAppearance.text(("Factory Reset"), redlineAppearance.revision);description:"Reset application preferences with backup. Hardware profiles are preserved.";kind:"action";actionText:"Reset UI settings";onRequested:snapshotDialog.showReset()}
     RedlineSettingRow{title:redlineAppearance.text(("Reset Game Stats"), redlineAppearance.revision);description:"Usage statistics are not tracked yet";kind:"action";actionText:"Perform Reset";supported:false;reason:"No game statistics database is connected."}
     RedlineSettingRow{title:redlineAppearance.text(("Issue Reporting"), redlineAppearance.revision);description:"Copy diagnostic system information for a report";kind:"action";actionText:"Copy diagnostics";onRequested:{systemInfo.copyToClipboard();page.preferenceSaved("Diagnostics copied")}}
     RedlineSettingRow{title:redlineAppearance.text(("Issue Detection"), redlineAppearance.revision);description:"Automatic problem detection";kind:"switch";supported:false;reason:"Automatic issue detection is not connected."}
     RedlineSettingRow{title:redlineAppearance.text(("About Redline"), redlineAppearance.revision);kind:"action";actionText:"About ›";onRequested:page.showAbout()}
    }
    Item{Layout.fillHeight:true}
   }
   ColumnLayout {
    visible:page.subpage==="System";Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:(settingsScroll.availableWidth-98)/2;Layout.alignment:Qt.AlignTop;Layout.margins:18;spacing:12
    RedlineSettingsGroup {
     heading:"Hardware & drivers"
     Rectangle {
      Layout.fillWidth:true;implicitHeight:116;color:redlineAppearance.color("#252528", redlineAppearance.revision)
      RowLayout {
       anchors.fill:parent;anchors.margins:18;spacing:22
       ColumnLayout {Layout.fillWidth:true;spacing:9
        Label{text:redlineAppearance.text(("GPU"), redlineAppearance.revision);color:redlineAppearance.color("#99999f", redlineAppearance.revision);font.pixelSize:12}
        Label{text:redlineAppearance.text((page.infoValue("gpu",["device","device name","graphics device","model"],page.infoGroup("gpu").name || "AMD graphics")), redlineAppearance.revision);wrapMode:Text.WordWrap;color:redlineAppearance.color("#ddd", redlineAppearance.revision);font.pixelSize:15;Layout.fillWidth:true}
       }
       Column {spacing:9
        Label{text:redlineAppearance.text(("VRAM reported"), redlineAppearance.revision);color:redlineAppearance.color("#99999f", redlineAppearance.revision);font.pixelSize:12}
        Label{text:redlineAppearance.text((nativeDashboard.systemInfo.vram), redlineAppearance.revision);color:redlineAppearance.color("#ddd", redlineAppearance.revision);font.pixelSize:16}
       }
      }
     }
     RedlineSettingsGroup {
      heading:"Hardware Details";collapsible:true;expanded:page.expandAll
      Repeater{model:page.infoGroup("gpu").rows;RedlineSettingRow{required property var modelData;title:redlineAppearance.text((modelData.title), redlineAppearance.revision);currentValue:modelData.value}}
     }
     RedlineSettingsGroup {
      heading:"Software & Driver Details";collapsible:true;expanded:page.expandAll
      RedlineSettingRow{title:redlineAppearance.text(("Operating system"), redlineAppearance.revision);currentValue:nativeDashboard.systemInfo.os}
      RedlineSettingRow{title:redlineAppearance.text(("Kernel"), redlineAppearance.revision);currentValue:nativeDashboard.systemInfo.kernel}
      RedlineSettingRow{title:redlineAppearance.text(("GPU driver"), redlineAppearance.revision);currentValue:nativeDashboard.systemInfo.driver}
      Repeater{model:page.infoGroup("software").rows;RedlineSettingRow{required property var modelData;title:redlineAppearance.text((modelData.title), redlineAppearance.revision);currentValue:modelData.value}}
     }
    }
    RedlineSettingsGroup {
     heading:"Processor & memory"
     RedlineSettingRow{title:redlineAppearance.text(("CPU"), redlineAppearance.revision);currentValue:nativeDashboard.systemInfo.cpuName}
     RedlineSettingRow{title:redlineAppearance.text(("System RAM"), redlineAppearance.revision);currentValue:nativeDashboard.systemInfo.memoryTotal}
     RedlineSettingsGroup {
      heading:"More Details";collapsible:true;expanded:page.expandAll
      RedlineSettingRow{title:redlineAppearance.text(("Laptop"), redlineAppearance.revision);currentValue:nativeDashboard.systemInfo.machine}
      RedlineSettingRow{title:redlineAppearance.text(("Architecture"), redlineAppearance.revision);currentValue:nativeDashboard.systemInfo.architecture}
      RedlineSettingRow{title:redlineAppearance.text(("Logical processors"), redlineAppearance.revision);currentValue:String(nativeDashboard.systemInfo.threads)}
      Repeater{model:page.infoGroup("cpu").rows;RedlineSettingRow{required property var modelData;title:redlineAppearance.text((modelData.title), redlineAppearance.revision);currentValue:modelData.value}}
     }
    }
    Item{Layout.fillHeight:true}
   }
   // DISPLAY: selected monitor, display options, separate color column.
   RowLayout {
    visible:page.subpage==="Display";Layout.columnSpan:2;Layout.fillWidth:true;Layout.margins:18
    Label{text:redlineAppearance.text(("Global Display"), redlineAppearance.revision);font.pixelSize:21;color:redlineAppearance.color("#eee", redlineAppearance.revision);Layout.fillWidth:true}
    ComboBox{visible:nativeDashboard.displays.length>1;model:nativeDashboard.displays.map(function(s){return s.name});onActivated:page.displayIndex=currentIndex}
    RedlineButton{text:"Refresh";onClicked:nativeDashboard.refreshDisplays()}
    RedlineButton{text:"Arrange Displays ↗";enabled:nativeDashboard.desktopSettingsAvailable();onClicked:nativeDashboard.openDesktopSettings("display")}
    RedlineButton{text:"Desktop Color ↗";enabled:nativeDashboard.desktopSettingsAvailable();onClicked:nativeDashboard.openDesktopSettings("color")}
   }
   Label {visible:page.subpage==="Display";Layout.columnSpan:2;Layout.fillWidth:true;Layout.leftMargin:18;Layout.rightMargin:18;text:redlineAppearance.text(((page.screen.manufacturer || "")+" "+(page.screen.model || page.screen.name || "No display detected")+"  ·  "+(page.screen.resolution || "")+"  ·  "+(page.screen.refreshRate || "")), redlineAppearance.revision);color:redlineAppearance.color("#999", redlineAppearance.revision);font.pixelSize:12}
   ColumnLayout {
    visible:page.subpage==="Display";Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:(settingsScroll.availableWidth-98)/2;Layout.alignment:Qt.AlignTop;Layout.margins:18;spacing:12
    RedlineSettingsGroup {
     heading:"Display Options"
     RedlineSettingRow{title:redlineAppearance.text(("Adaptive Sync"), redlineAppearance.revision);description:"Variable refresh rate";kind:"switch";supported:false;reason:"No verified compositor capability is connected for this display."}
     RedlineSettingRow{title:redlineAppearance.text(("Virtual Super Resolution"), redlineAppearance.revision);kind:"switch";supported:false;description:"Per-game supersampling needs a separate Linux implementation.";reason:"Desktop-wide VSR control is not connected in Redline."}
     RedlineSettingRow{title:redlineAppearance.text(("GPU Scaling"), redlineAppearance.revision);kind:"switch";supported:false;reason:"GPU scaling is not exposed through the current Redline display backend."}
     RedlineSettingRow{title:redlineAppearance.text(("Scaling Mode"), redlineAppearance.revision);kind:"choice";choices:["Not available"];supported:false;reason:"Use Ubuntu display settings for desktop scaling."}
     RedlineSettingRow{title:redlineAppearance.text(("Integer Scaling"), redlineAppearance.revision);currentValue:"Not available";supported:false;reason:"No integer-scaling capability is connected."}
     RedlineSettingRow{title:redlineAppearance.text(("Color Depth"), redlineAppearance.revision);currentValue:page.screen.depth;description:"Reported Qt surface depth; not the monitor link bit depth"}
     RedlineSettingRow{title:redlineAppearance.text(("Pixel Format"), redlineAppearance.revision);currentValue:"Not reported";reason:"Pixel format is not reported by the current display model."}
     RedlineSettingRow{title:redlineAppearance.text(("Display Color Enhancement"), redlineAppearance.revision);kind:"choice";choices:["Not available"];supported:false;reason:"Color enhancement backend is not connected."}
    }
    RedlineSettingsGroup {
     heading:"Connected Display Details";collapsible:true;expanded:page.expandAll
     RedlineSettingRow{title:redlineAppearance.text(("Connector / screen"), redlineAppearance.revision);currentValue:page.screen.name}
     RedlineSettingRow{title:redlineAppearance.text(("Desktop size"), redlineAppearance.revision);currentValue:page.screen.resolution;description:"Logical size reported by Qt"}
     RedlineSettingRow{title:redlineAppearance.text(("Refresh rate"), redlineAppearance.revision);currentValue:page.screen.refreshRate}
     RedlineSettingRow{title:redlineAppearance.text(("Qt scale factor"), redlineAppearance.revision);currentValue:page.screen.scale}
     RedlineSettingRow{title:redlineAppearance.text(("Physical size"), redlineAppearance.revision);currentValue:page.screen.physicalSize}
    }
    Item{Layout.fillHeight:true}
   }
   ColumnLayout {
    visible:page.subpage==="Display";Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:(settingsScroll.availableWidth-98)/2;Layout.alignment:Qt.AlignTop;Layout.margins:18;spacing:12
    RedlineSettingsGroup {
     heading:"Custom Color"
     RedlineSettingRow{title:redlineAppearance.text(("Custom Color"), redlineAppearance.revision);description:"Modify display color reproduction";kind:"switch";supported:false;reason:"No color adjustment backend is connected."}
     RedlineSettingRow{title:redlineAppearance.text(("Color Deficiency Correction"), redlineAppearance.revision);kind:"switch";supported:false;reason:"No accessibility color-filter backend is connected."}
     RedlineSettingsGroup{heading:"Custom Resolutions";collapsible:true;expanded:page.expandAll;RedlineSettingRow{title:redlineAppearance.text(("Custom display modes"), redlineAppearance.revision);currentValue:"Not available";description:"Use the operating system's supported display modes"}}
     RedlineSettingsGroup{heading:"Overrides";collapsible:true;expanded:page.expandAll;RedlineSettingRow{title:redlineAppearance.text(("Driver overrides"), redlineAppearance.revision);currentValue:"Not available";description:"Redline does not modify display driver configuration"}}
    }
    RedlineSettingsGroup {
     heading:"Display Tools"
     RedlineSettingRow{title:redlineAppearance.text(("Ubuntu Display Settings"), redlineAppearance.revision);description:"Arrange monitors, resolution and desktop scaling";kind:"action";actionText:"Open ↗";supported:nativeDashboard.desktopSettingsAvailable();onRequested:nativeDashboard.openDesktopSettings("display")}
     RedlineSettingRow{title:redlineAppearance.text(("Color Management"), redlineAppearance.revision);description:"Manage color profiles in Ubuntu Settings";kind:"action";actionText:"Open ↗";supported:nativeDashboard.desktopSettingsAvailable();onRequested:nativeDashboard.openDesktopSettings("color")}
     RedlineSettingRow{title:redlineAppearance.text(("Privacy View"), redlineAppearance.revision);currentValue:"Not available";reason:"No privacy-view service is connected."}
    }
    Item{Layout.fillHeight:true}
   }
   // PREFERENCES: supported choices write the real application settings.
   ColumnLayout {
    visible:page.subpage==="Preferences";Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:(settingsScroll.availableWidth-98)/2;Layout.alignment:Qt.AlignTop;Layout.margins:18;spacing:12
    RedlineSettingsGroup {
     heading:"General"
     RedlineSettingRow{title:redlineAppearance.text(("In-Game Overlay"), redlineAppearance.revision);description:"MangoHud metrics overlay for connected game launches. Restart the game after changes.";kind:"switch";supported:gamingTools.available().overlay || gamingTools.available("snap").overlay;currentValue:{var r=page.store.revision;return page.store.read("perf.overlay",true)} onRequested:value=>page.store.write("perf.overlay",value)}
     RedlineSettingRow{title:redlineAppearance.text(("Web Browser"), redlineAppearance.revision);kind:"switch";supported:false;reason:"No embedded web browser is included."}
     RedlineSettingRow{objectName:"trayPreference";title:redlineAppearance.text(("System Tray Menu"), redlineAppearance.revision);supported:typeof systemTray!=="undefined" && systemTray.isAvailable();reason:"Requires a desktop system-tray host";description:"Show Redline in the desktop system tray";kind:"switch";currentValue:page.preference("sysTray",true);onRequested:value=>page.updatePreference("sysTray",value)}
     RedlineSettingRow{title:redlineAppearance.text(("Advertisements"), redlineAppearance.revision);kind:"switch";supported:false;reason:"No advertisement service is implemented."}
     RedlineSettingRow{objectName:"toastPreference";title:redlineAppearance.text(("Toast Notifications"), redlineAppearance.revision);description:"Show confirmations for saved application preferences";kind:"switch";currentValue:page.preference("Ui/toastNotifications",true);onRequested:value=>page.updatePreference("Ui/toastNotifications",value)}
     RedlineSettingRow{title:redlineAppearance.text(("Game Adjustment Tracking"), redlineAppearance.revision);kind:"switch";supported:false;reason:"Game adjustment tracking is not implemented."}
     RedlineSettingRow{title:redlineAppearance.text(("Tutorials"), redlineAppearance.revision);kind:"switch";supported:false;reason:"An in-app tutorial service is not connected."}
     RedlineSettingRow{title:redlineAppearance.text(("Theme"), redlineAppearance.revision);kind:"choice";choices:["Dark","Light"];currentValue:page.preference("Ui/theme","Dark");onRequested:value=>page.updatePreference("Ui/theme",value)}
     RedlineSettingRow{title:redlineAppearance.text(("Language"), redlineAppearance.revision);kind:"choice";choices:["English","Ελληνικά"];currentValue:page.preference("Ui/language","English");onRequested:value=>page.updatePreference("Ui/language",value)}
     RedlineSettingRow{title:redlineAppearance.text(("Always On Top"), redlineAppearance.revision);kind:"switch";supported:false;reason:"Always-on-top integration is not verified for this desktop compositor."}
     RedlineSettingRow{title:redlineAppearance.text(("Sidebar Position"), redlineAppearance.revision);kind:"choice";choices:["Not available"];supported:false;reason:"The application uses the top navigation bar."}
     RedlineSettingRow{objectName:"animationsPreference";title:redlineAppearance.text(("Animation & Effects"), redlineAppearance.revision);description:"Animate application confirmation messages";kind:"switch";currentValue:page.preference("Ui/animations",true);onRequested:value=>page.updatePreference("Ui/animations",value)}
    }
    Item{Layout.fillHeight:true}
   }
   ColumnLayout {
    visible:page.subpage==="Preferences";Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:(settingsScroll.availableWidth-98)/2;Layout.alignment:Qt.AlignTop;Layout.margins:18;spacing:12
    RedlineSettingsGroup {
     heading:"Startup & window"
     RedlineSettingRow{objectName:"startupPreference";title:redlineAppearance.text(("Start Minimized"), redlineAppearance.revision);description:"Start in the system tray when Redline is launched";kind:"switch";currentValue:page.preference("startOnSysTray",false);supported:page.preference("sysTray",true);reason:page.preference("sysTray",true)?"":"Enable the system tray before starting minimized.";onRequested:value=>page.updatePreference("startOnSysTray",value)}
     RedlineSettingRow{objectName:"geometryPreference";title:redlineAppearance.text(("Remember Window Geometry"), redlineAppearance.revision);description:"Restore the saved application window size";kind:"switch";currentValue:page.preference("saveWindowGeometry",true);onRequested:value=>page.updatePreference("saveWindowGeometry",value)}
    }
    RedlineSettingsGroup {
     heading:"Data & Privacy"
     RedlineSettingRow{title:redlineAppearance.text(("User Experience Program"), redlineAppearance.revision);currentValue:"Not implemented";description:"No subscription control is connected"}
    }
    RedlineSettingsGroup {
     heading:"Gameplay"
     RedlineSettingRow{title:redlineAppearance.text(("Image Inspector"), redlineAppearance.revision);kind:"switch";supported:false;reason:"No image-inspection service is connected."}
    }
    RedlineSettingsGroup {
     heading:"VR Streaming"
     RedlineSettingRow{title:redlineAppearance.text(("VR Streaming"), redlineAppearance.revision);currentValue:"Not available";description:"A VR streaming service is not connected"}
    }
    Item{Layout.fillHeight:true}
   }
   RedlineVR {
    id:vrPage
    store:page.store
    visible:page.subpage==="ReLive VR";Layout.columnSpan:2;Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:settingsScroll.availableWidth-36;Layout.maximumWidth:settingsScroll.availableWidth-36;Layout.alignment:Qt.AlignLeft|Qt.AlignTop;Layout.margins:18
   }
  }
 }
}
