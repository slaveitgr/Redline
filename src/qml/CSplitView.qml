// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2025 Juan Palacios <jpalaciosdev@gmail.com>

import QtQuick 2.15
import QtQuick.Controls 2.15
import "Style.js" as Style

SplitView {
  id: spv
  spacing: 0

  handle: Rectangle {
    implicitWidth: spv.orientation === Qt.Horizontal ? Style.Split.thickness
                                                     : spv.width
    implicitHeight: spv.orientation === Qt.Horizontal ? spv.height
                                                     : Style.Split.thickness
    color: !spv.enabled ? Qt.lighter(redlineAppearance.color(Style.Split.background, redlineAppearance.revision), 1.20)
                        : SplitHandle.hovered ? Qt.lighter(redlineAppearance.color(Style.Split.background, redlineAppearance.revision), 1.15)
                                              : redlineAppearance.color(Style.Split.background, redlineAppearance.revision)
    Rectangle {
      color: redlineAppearance.color(Style.Split.Handle.background, redlineAppearance.revision)
      width: spv.orientation === Qt.Horizontal ? Style.Split.Handle.thickness
                                               : Style.Split.Handle.length
      height: spv.orientation === Qt.Horizontal ? Style.Split.Handle.length
                                                : Style.Split.Handle.thickness
      x: parent ? (parent.width - width) / 2 : 0
      y: parent ? (parent.height - height) / 2 : 0
    }
  }
}
