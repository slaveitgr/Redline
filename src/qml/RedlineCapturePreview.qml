// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
Item {
 id:root
 implicitHeight:240
 Image {anchors.fill:parent;fillMode:Image.PreserveAspectFit;cache:false;asynchronous:false;source:captureBackend.previewAvailable?"image://capture/frame/"+captureBackend.previewFrame:""}
}
