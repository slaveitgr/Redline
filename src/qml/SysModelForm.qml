// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2019 Juan Palacios <jpalaciosdev@gmail.com>

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import CoreCtrl.UIComponents 1.0
import "Style.js" as Style

SYS_MODEL {
  id: sysModel
  objectName: "SYS_MODEL"

  anchors.fill: parent

  ScrollView {
    id: workspace
    anchors.fill: parent
    anchors.margins: 18
    contentWidth: availableWidth
    clip: true
    Column {
     width: workspace ? workspace.availableWidth : 0
     spacing:20
     RedlineGpuTuning {width:parent.width}
     Column {
      id: sysModelplug
      objectName: "SYS_MODEL_Plug"
      width: workspace ? workspace.availableWidth : 0
      spacing: 20
      property var childrenAdded: []
      onChildrenChanged: {
        for (var i=0;i<children.length;i++) {
          var component=children[i]
          if(childrenAdded.indexOf(component)>=0)continue
          childrenAdded.push(component)
          component.width=Qt.binding(function(){return sysModelplug.width})
          component.height=Qt.binding(function(){return Math.max(420,this.implicitHeight)})
          sysModel.setupChild(component)
        }
      }
     }
    }
  }
}
