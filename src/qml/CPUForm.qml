// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2019 Juan Palacios <jpalaciosdev@gmail.com>

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import CoreCtrl.UIComponents 1.0
import "Style.js" as Style
import "Settings.js" as Settings

CPU {
  id: cpu
  objectName: "CPU"

  implicitHeight: Math.max(420,flow.childrenRect.height+280)

  onNewGraphItem: item => {
    sensorGraph.addItem(item)
    Settings.addComponentData("CPU" + cpu.physicalId, "CPU " + cpu.physicalId,
                              item.name,
                              qsTranslate("SensorGraph", item.name))
  }

  Connections {
    target: settings

    function onSettingChanged(key, value) {
      if (key === "Workarounds/ignoredSensors") {
        var sensors = Settings.componentIgnoredSensors("CPU" + cpu.physicalId,
                                                        value)
        sensorGraph.ignoredSensors(sensors)
      }
      else if (key === "UI/splitview-sysmodel-sensorgraph-height") {
        sensorGraph.SplitView.preferredHeight = value
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 1
    Rectangle {
      Layout.fillWidth: true; Layout.preferredHeight: 40
      color: redlineAppearance.color("#18181b",redlineAppearance.revision)
      RowLayout {
        anchors.fill: parent; anchors.margins: 10
        Label {text: "CPU";color:redlineAppearance.color("#eee",redlineAppearance.revision);font.bold:true}
        Label {text: cpu.name;Layout.fillWidth:true;elide:Text.ElideRight;color:redlineAppearance.color("#aaa",redlineAppearance.revision)}
        Label {text:redlineAppearance.text(redlineReadOnly?"Read-only preview":"Tuning Control",redlineAppearance.revision);color:redlineAppearance.color("#999",redlineAppearance.revision)}
      }
    }
    Rectangle {
      Layout.fillWidth:true;Layout.preferredHeight:Math.max(92,flow.childrenRect.height+24)
      color:redlineAppearance.color("#252528",redlineAppearance.revision)
      Flow {
        id:flow
        objectName:"CPU_Plug"
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:12
        spacing:12
        property var childrenAdded:[]
        onChildrenChanged: {
          for(var i=0;i<children.length;i++)if(childrenAdded.indexOf(children[i])<0){childrenAdded.push(children[i]);cpu.setupChild(children[i])}
        }
      }
    }
    Label {text:redlineAppearance.text("Hardware Gauges",redlineAppearance.revision);color:redlineAppearance.color("#aaa",redlineAppearance.revision);Layout.topMargin:10}
    SensorGraph {id:sensorGraph;Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:150}
  }
}
