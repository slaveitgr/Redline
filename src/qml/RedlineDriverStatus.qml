// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
RedlineSettingsGroup {
 heading:"Drivers & Updates"
 RedlineSettingRow {title:"Operating system";currentValue:systemIntegration.driver.os}
 RedlineSettingRow {title:"Kernel / Architecture";currentValue:systemIntegration.driver.kernel+" / "+systemIntegration.driver.architecture}
 Repeater {model:systemIntegration.driver.devices || [];RedlineSettingRow {required property var modelData;title:"GPU · "+modelData.card;currentValue:modelData.driver+" · "+modelData.vendor+":"+modelData.device}}
 RedlineSettingRow {title:"Installed graphics packages";currentValue:systemIntegration.driver.packages}
 RedlineSettingRow {title:"AMD vendor package";currentValue:"Radeon Software for Linux "+systemIntegration.driver.release;description:"Package components have different licenses. This is not a verified proprietary-only driver."}
 RedlineSettingRow {title:"Official OS targets";currentValue:systemIntegration.driver.supported}
 RedlineSettingRow {title:"Compatibility";currentValue:systemIntegration.driver.status;description:"A listed OS alone does not validate your GPU, kernel or point release."}
 RedlineSettingRow {title:"Catalog checked";currentValue:systemIntegration.driver.verified;description:"Versioned reference catalog. Open AMD for current releases; this is not a live update check."}
 RowLayout {
  Layout.fillWidth:true
  RedlineButton {text:"Refresh system";Layout.fillWidth:true;onClicked:systemIntegration.refresh()}
  RedlineButton {text:"AMD downloads ↗";accent:true;Layout.fillWidth:true;onClicked:systemIntegration.openReference("amd")}
 }
 RedlineButton {text:"Release notes ↗";Layout.fillWidth:true;onClicked:systemIntegration.openReference("release")}
 Label {text:redlineAppearance.text("No driver, repository or kernel changes are performed by this compatibility check.",redlineAppearance.revision);color:redlineAppearance.color("#999",redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.margins:12}
}
