// SPDX-License-Identifier: GPL-3.0-or-later
// Layout follows the supplied dashboard v2 HTML; values come from the local model.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id: home
 signal openAI(string prompt)
 signal openGames()
 signal openCapture()
 signal openReplay()
 signal openGame(string id)
 signal openGraphics()
 signal openProfiles()
 signal openPerformance()
 signal openSettings()
 signal showDetails(string title, string message)
 component Small: Label { color: redlineAppearance.color("#a4a4aa", redlineAppearance.revision); font.pixelSize: 11; wrapMode: Text.WordWrap }
 RowLayout {
  anchors.fill: parent; anchors.margins: 14; spacing: 14
  ColumnLayout {
   Layout.preferredWidth: home.width > 1300 ? 295 : 250; Layout.minimumWidth: 240; Layout.maximumWidth: home.width > 1300 ? 295 : 250; Layout.fillHeight: true; spacing: 13
   RedlineCard {
    heading: "GLOBAL EXPERIENCE"; Layout.fillWidth: true; Layout.preferredHeight: home.height < 730 ? 165 : 184
    Rectangle {
     anchors.fill: parent
     gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: redlineAppearance.color("#48484e", redlineAppearance.revision) } GradientStop { position: 1; color: redlineAppearance.color("#27272b", redlineAppearance.revision) } }
     ColumnLayout {
      anchors.fill: parent; anchors.margins: 14; spacing: 10
      Label { text: redlineAppearance.text(("Global graphics"), redlineAppearance.revision); font.pixelSize: 19; color: redlineAppearance.color("#ededf0", redlineAppearance.revision); Layout.alignment: Qt.AlignHCenter }
      Small { text: redlineAppearance.text(("Manage performance & power profiles"), redlineAppearance.revision); Layout.alignment: Qt.AlignHCenter }
      RedlineButton { text: "Configure"; accent: true; Layout.fillWidth: true; onClicked: home.openGraphics() }
     }
    }
   }
   RedlineCard {
    heading: "LIVE PERFORMANCE"; Layout.fillWidth: true; Layout.preferredHeight: home.height < 730 ? 140 : 171
    ColumnLayout {
     anchors.fill:parent;anchors.margins:14;spacing:8
     RowLayout {
      Layout.fillWidth:true
      Repeater {model:[{label:"GPU",key:"gpu"},{label:"Temperature",key:"temperature"}]
       ColumnLayout {required property var modelData;Layout.fillWidth:true;Layout.preferredWidth:1
        Small {text:redlineAppearance.text(modelData.label,redlineAppearance.revision)}
        Label {text:nativeDashboard.metrics[modelData.key] || "N/A";font.pixelSize:20;color:redlineAppearance.color("#eee",redlineAppearance.revision)}
       }
      }
     }
     RedlineButton {text:"Open Metrics";Layout.fillWidth:true;onClicked:home.openPerformance()}
    }
   }
   RedlineCard {
    heading: "MEDIA & CAPTURE"; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: home.height < 730 ? 245 : 275
    ColumnLayout {
     anchors.fill: parent; spacing: 0
     Rectangle {
      Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 75; color: redlineAppearance.color("#0c0c0f", redlineAppearance.revision)
      Label { anchors.centerIn: parent; text: redlineAppearance.text(("▷"), redlineAppearance.revision); font.pixelSize: 32; color: redlineAppearance.color("#73737b", redlineAppearance.revision) }
      Small { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; text: redlineAppearance.text(captureBackend.active?"Recording in progress":captureBackend.supported?"Recording & screenshots":"Screenshot portal available", redlineAppearance.revision)}
     }
     GridLayout {
      columns: 2; rowSpacing: 1; columnSpacing: 1; Layout.fillWidth: true
      Repeater {
       model: [{symbol:"▣",label:"Take a Screenshot"},{symbol:"⦿",label:"Record a Video"},{symbol:"↶",label:"Instant Replay"},{symbol:"◉",label:"Instant GIF"}]
       Rectangle {
        required property var modelData
        Layout.fillWidth: true; Layout.preferredHeight: home.height < 730 ? 70 : 91; color: redlineAppearance.color("#28282b", redlineAppearance.revision)
        Column { anchors.centerIn: parent; spacing: 10
         Label { text: redlineAppearance.text((modelData.symbol), redlineAppearance.revision); font.pixelSize: 28; color: modelData.label!=="Instant GIF"?"#ed003b":redlineAppearance.color("#854254",redlineAppearance.revision); anchors.horizontalCenter: parent.horizontalCenter }
         Small { text: redlineAppearance.text((modelData.label), redlineAppearance.revision); color: redlineAppearance.color("#77777e", redlineAppearance.revision) }
        }
        MouseArea { enabled:modelData.label!=="Instant GIF";anchors.fill: parent; onClicked:{if(modelData.label==="Take a Screenshot")captureBackend.takeScreenshot();else if(modelData.label==="Record a Video")home.openCapture();else if(modelData.label==="Instant Replay")home.openReplay()}}
       }
      }
     }
    }
   }
  }
  ColumnLayout {
   Layout.fillWidth: true; Layout.minimumWidth: 350; Layout.fillHeight: true; spacing: 13
   RedlineCard {
    heading: "GAMES"; Layout.fillWidth: true; Layout.preferredHeight: home.height < 730 ? 310 : 354
    RowLayout {
     anchors.fill: parent; spacing: 1
     Repeater {
      model: Math.min(3, nativeDashboard.games.length)
      Rectangle {
       required property int index
       property var game: nativeDashboard.games[index]
       Layout.fillWidth: true; Layout.fillHeight: true; color: redlineAppearance.color("#252528", redlineAppearance.revision)
       ColumnLayout {
        anchors.fill: parent; spacing: 0
        Image { source: game.art; Layout.fillWidth: true; Layout.preferredHeight: home.height < 730 ? 85 : 115; fillMode: Image.PreserveAspectCrop; clip: true; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:home.openGame(game.id)} }
        Label { text: game.name; Layout.fillWidth: true; Layout.margins: 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; color: redlineAppearance.color("#ddd", redlineAppearance.revision); font.pixelSize: 15 }
        RowLayout {
         Layout.fillWidth: true
         Repeater { model: ["Play Total", "Avg. FPS"]
          Column { required property string modelData; Layout.fillWidth: true; spacing: 5
           Small { text: redlineAppearance.text((modelData), redlineAppearance.revision); anchors.horizontalCenter: parent.horizontalCenter }
           Label { text: redlineAppearance.text(("—"), redlineAppearance.revision); color: redlineAppearance.color("#ccc", redlineAppearance.revision); font.pixelSize: 19; anchors.horizontalCenter: parent.horizontalCenter }
          }
         }
        }
        Item { Layout.fillHeight: true }
        Rectangle { Layout.fillWidth: true; height: 1; color: redlineAppearance.color("#17171a", redlineAppearance.revision) }
        Item {
         Layout.fillWidth: true; Layout.preferredHeight: 96
         Column { anchors.centerIn: parent; spacing: 7
          Rectangle { width: 36; height: 36; radius: 18; color: redlineAppearance.color("#ed003e", redlineAppearance.revision); anchors.horizontalCenter: parent.horizontalCenter; Label { anchors.centerIn: parent; text: redlineAppearance.text(("▷"), redlineAppearance.revision); font.pixelSize: 22; color: redlineAppearance.color("white", redlineAppearance.revision) } }
          Small { text: redlineAppearance.text(("Game profile"), redlineAppearance.revision); anchors.horizontalCenter: parent.horizontalCenter }
          Small { text: redlineAppearance.text(("⌄"), redlineAppearance.revision); anchors.horizontalCenter: parent.horizontalCenter }
         }
         MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.openGame(game.id) }
        }
       }
      }
     }
     ColumnLayout {visible:nativeDashboard.games.length===0;Layout.fillWidth:true;Layout.fillHeight:true
      Item {Layout.fillHeight:true}
      Label {text:"▷";font.pixelSize:44;color:redlineAppearance.color("#999",redlineAppearance.revision);Layout.alignment:Qt.AlignHCenter}
      Small {text:redlineAppearance.text("No installed Steam games found",redlineAppearance.revision);Layout.alignment:Qt.AlignHCenter}
      RedlineButton {text:"Browse Games";accent:true;Layout.alignment:Qt.AlignHCenter;onClicked:home.openGames()}
      Item {Layout.fillHeight:true}
     }
    }
   }
   RedlineButton {text:"Browse Games";Layout.fillWidth:true;onClicked:home.openGames()}
   Rectangle {
    Layout.fillWidth: true; Layout.fillHeight: true; color: redlineAppearance.color("#0a0a0c", redlineAppearance.revision); clip: true
    Image { anchors.fill: parent; source: "images/feature.svg"; fillMode: Image.PreserveAspectCrop }
   }
  }
  ColumnLayout {
   Layout.preferredWidth: home.width > 1300 ? 295 : 250; Layout.minimumWidth: 240; Layout.maximumWidth: home.width > 1300 ? 295 : 250; Layout.fillHeight: true; spacing: 13
   RedlineCard {
    heading: "DRIVER & SOFTWARE"; Layout.fillWidth: true; Layout.preferredHeight: home.height < 730 ? 165 : 184
    ColumnLayout {
     anchors.fill: parent; spacing: 0
     RowLayout {
      Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 14
      Column { Layout.fillWidth: true; spacing: 7
       Small { text: redlineAppearance.text(("Software Version"), redlineAppearance.revision)}
       Label { text: redlineAppearance.text((appInfo.version), redlineAppearance.revision); font.pixelSize: 19; color: redlineAppearance.color("#ddd", redlineAppearance.revision) }
       Small { text: redlineAppearance.text(("Redline"), redlineAppearance.revision)}
      }
      Column { Layout.fillWidth: true; spacing: 7
       Small { text: redlineAppearance.text(("Status"), redlineAppearance.revision)}
       Label { text: redlineAppearance.text((redlineReadOnly ? "Preview" : redlineGpu.writable ? "Ready" : "Setup required"), redlineAppearance.revision); font.pixelSize: 19; color: redlineAppearance.color("#ddd", redlineAppearance.revision) }
       Small { text: redlineAppearance.text(("Linux graphics"), redlineAppearance.revision)}
      }
     }
     RowLayout {
      Layout.fillWidth: true; spacing: 1
      RedlineButton { text: "System Info ↗"; Layout.fillWidth: true; onClicked: home.openSettings() }
      RedlineButton { text: "Settings ›"; accent: true; Layout.fillWidth: true; onClicked: home.openSettings() }
     }
    }
   }
   RedlineCard {
    heading: "REDLINE CHAT"; Layout.fillWidth: true; Layout.fillHeight: true
    ColumnLayout {
     anchors.fill: parent; anchors.margins: 15; spacing: 10
     Item { Layout.fillHeight: true; Layout.minimumHeight: 5 }
     Label { text: redlineAppearance.text(("›"), redlineAppearance.revision); font.pixelSize: 55; color: redlineAppearance.color("#ed003e", redlineAppearance.revision); Layout.alignment: Qt.AlignHCenter }
     Label { text: redlineAppearance.text(("Redline Chat"), redlineAppearance.revision); color: redlineAppearance.color("#bfbfc4", redlineAppearance.revision); font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
     Small { text: redlineAppearance.text(("Your Linux gaming assistant"), redlineAppearance.revision); Layout.alignment: Qt.AlignHCenter }
     Item { Layout.fillHeight: true }
     Repeater {
      model: [{q:"What is my GPU temperature?",key:"temperature",label:"GPU temperature"},{q:"What is my GPU utilization?",key:"gpu",label:"GPU utilization"},{q:"How much memory is in use?",key:"memory",label:"RAM used / total"},{q:"What is my GPU clock?",key:"clock",label:"GPU clock"}]
      RedlineButton {
       required property var modelData
       text: modelData.q; Layout.fillWidth: true; implicitHeight: 39
       background: Rectangle { radius: 22; color: parent.hovered ? redlineAppearance.color("#414147", redlineAppearance.revision) : redlineAppearance.color("#303035", redlineAppearance.revision); border.color: redlineAppearance.color("#17171b", redlineAppearance.revision) }
       onClicked: home.openAI(modelData.q)
      }
     }
     Item { Layout.fillHeight: true }
     RedlineButton {text:"Open Chat";accent:true;Layout.fillWidth:true;onClicked:home.openAI("")}
     Small {text:redlineAppearance.text("Connect your local AI model",redlineAppearance.revision);Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter}
    }
   }
  }
 }
}
