// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "FeatureCatalog.js" as Catalog
ScrollView {
 id: page
 property string pageKey: ""
 property var store
 property bool inherited: false
 property bool hardwarePage: pageKey.indexOf("Graphics") >= 0 || pageKey.indexOf("Display") >= 0 || pageKey.indexOf("Smart Technology") >= 0 || pageKey.indexOf("Hotkeys") >= 0 || pageKey.indexOf("Audio & Video") >= 0
 signal openHardware()
 signal details(string title, string message)
 clip: true
 contentWidth: availableWidth
 ColumnLayout {
  width: page.availableWidth; spacing: 1
  Item { Layout.preferredHeight: 12 }
  RowLayout {
   Layout.fillWidth: true; Layout.margins: 14
   Label { text: redlineAppearance.text((page.pageKey.replace("/", " / ")), redlineAppearance.revision); font.pixelSize: 21; color: redlineAppearance.color("#eee", redlineAppearance.revision); Layout.fillWidth: true }
   RedlineButton { text: "GPU / CPU controls ›"; accent: true; visible: page.hardwarePage; onClicked: page.openHardware() }
  }
  Label { text: redlineAppearance.text((page.hardwarePage ? "Availability depends on your Linux hardware and backend. Open GPU / CPU controls for supported tuning." : "Capture and streaming are not connected. These controls save setup preferences only; no recording or broadcast starts."), redlineAppearance.revision); wrapMode: Text.WordWrap; color: redlineAppearance.color("#999", redlineAppearance.revision); Layout.fillWidth: true; Layout.margins: 14 }
  RedlineSettingRow {
   visible:page.pageKey==="Settings/Hotkeys";Layout.leftMargin:14;Layout.rightMargin:14
   title:"Toggle Metrics Overlay";description:"In-game MangoHud shortcut. Restart the game after changing it.";kind:"choice";choices:["Shift+F12","Shift+F11","Ctrl+F12"]
   currentValue:{var r=page.store.revision;return page.store.read("perf.overlay.hotkey","Shift_R+F12").replace("Shift_R","Shift").replace("Control_R","Ctrl")}
   onRequested:value=>page.store.write("perf.overlay.hotkey",value.replace("Shift+","Shift_R+").replace("Ctrl+","Control_R+"))
  }
  Repeater {
   model: Catalog.pages[page.pageKey] || []
   Rectangle {
    id: settingRow
    required property var modelData
    Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14
    implicitHeight: Math.max(62, label.implicitHeight + (modelData.description ? 40 : 24))
    color: redlineAppearance.color("#252528", redlineAppearance.revision)
    RowLayout {
     anchors.fill: parent; anchors.margins: 14; spacing: 18
     ColumnLayout {
      Layout.fillWidth:true;spacing:4
      Label { id: label; text: redlineAppearance.text((settingRow.modelData.label), redlineAppearance.revision); color: redlineAppearance.color("#ddd", redlineAppearance.revision); wrapMode: Text.WordWrap; Layout.fillWidth: true; font.pixelSize:13 }
      Label {text:redlineAppearance.text((settingRow.modelData.description || ""), redlineAppearance.revision);visible:text.length>0;color:redlineAppearance.color("#88888f", redlineAppearance.revision);font.pixelSize:11;wrapMode:Text.WordWrap;Layout.fillWidth:true}
     }
     Label { visible: settingRow.modelData.type === "switch"; text: redlineAppearance.text((page.hardwarePage ? "Unavailable" : toggle.checked ? "Enabled" : "Disabled"), redlineAppearance.revision); color: redlineAppearance.color("#999", redlineAppearance.revision); Layout.preferredWidth: visible ? 76 : 0 }
     Switch {
      id: toggle
      visible: settingRow.modelData.type === "switch"
      enabled: !page.hardwarePage && !page.inherited
      checked: { var revision = page.store.revision; return page.hardwarePage ? false : Boolean(page.store.read(settingRow.modelData.key, settingRow.modelData.initial)) }
      onToggled: page.store.write(settingRow.modelData.key, checked)
     }
     ComboBox {
      visible: settingRow.modelData.type === "select"; Layout.preferredWidth: visible ? 230 : 0
      model: settingRow.modelData.options || []
      enabled: !page.hardwarePage && !page.inherited
      currentIndex: { var revision = page.store.revision; return Math.max(0, model.indexOf(page.store.read(settingRow.modelData.key,settingRow.modelData.initial))) }
      onActivated: page.store.write(settingRow.modelData.key,currentText)
     }
     RowLayout {
      visible: settingRow.modelData.type === "range"
      Label { text: redlineAppearance.text((slider.value.toFixed(0)), redlineAppearance.revision); color: redlineAppearance.color("#bbb", redlineAppearance.revision) }
      Slider {
       id: slider; Layout.preferredWidth: 190
       from: settingRow.modelData.min || 0; to: settingRow.modelData.max || 100; stepSize: settingRow.modelData.step || 1
       value: { var revision = page.store.revision; return Number(page.store.read(settingRow.modelData.key,settingRow.modelData.initial)) }
       onMoved: page.store.write(settingRow.modelData.key,value)
      }
     }
     TextField {
      visible:settingRow.modelData.type==="text";Layout.preferredWidth:visible?270:0
      text:{var rev=page.store.revision;return String(page.store.read(settingRow.modelData.key,settingRow.modelData.initial))}
      onEditingFinished:page.store.write(settingRow.modelData.key,text)
     }
     Label {visible:settingRow.modelData.type==="info";text:redlineAppearance.text((settingRow.modelData.initial || "Unavailable"), redlineAppearance.revision);color:redlineAppearance.color("#999", redlineAppearance.revision)}
     RedlineButton { visible: settingRow.modelData.type === "action"; text: settingRow.modelData.action || "Unavailable"; enabled: false }
    }
   }
  }
  Label { visible: !(Catalog.pages[page.pageKey] || []).length; text: redlineAppearance.text((page.pageKey === "AI/Apps" ? "No AI apps connected." : page.pageKey === "Gaming/Advisors" ? "Game assessments require recorded performance data." : "This workspace is ready for integration. The service is not connected yet."), redlineAppearance.revision); color: redlineAppearance.color("#999", redlineAppearance.revision); Layout.margins: 22 }
  RedlineCard {
   visible: page.pageKey === "AI/Chat"; heading: "SYSTEM ASSISTANT"; Layout.fillWidth: true; Layout.margins: 14; Layout.preferredHeight: 250
   ColumnLayout {
    anchors.fill: parent; anchors.margins: 18
    Repeater {
     model: [{label:"GPU temperature",key:"temperature"},{label:"GPU utilization",key:"gpu"},{label:"System memory",key:"memory"}]
     RedlineButton { required property var modelData; text: modelData.label + " · " + (nativeDashboard.metrics[modelData.key] || "N/A"); Layout.fillWidth: true; onClicked: page.details(modelData.label,nativeDashboard.metrics[modelData.key] || "N/A") }
    }
   }
  }
  Item { Layout.preferredHeight: 20 }
 }
}
