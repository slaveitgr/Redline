// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2025 Juan Palacios <jpalaciosdev@gmail.com>

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Style.js" as Style

TabButton {
  id: btn
  implicitHeight: 48

  contentItem: Text {
    text: btn.text
    font: btn.font
    color: btn.checked ? redlineAppearance.color(Style.Theme.accent, redlineAppearance.revision)
                       : redlineAppearance.color(Style.Theme.foreground, redlineAppearance.revision)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  background: ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // active accent
    Rectangle {
      visible: btn.checked
      color: redlineAppearance.color(Style.Theme.accent, redlineAppearance.revision)
      Layout.preferredHeight: 2
      Layout.fillWidth: true
    }
    // content
    Rectangle {
      color: btn.hovered ? redlineAppearance.color(Style.TabBar.Button.MainFooter.background_alt, redlineAppearance.revision)
                         : redlineAppearance.color(Style.TabBar.Button.MainFooter.background, redlineAppearance.revision)
      Layout.fillWidth: true
      Layout.fillHeight: true
    }
  }
}
