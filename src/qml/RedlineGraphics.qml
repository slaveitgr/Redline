// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ScrollView {
 id:page
 property var store
 signal openGames()
 contentWidth:availableWidth;clip:true
 ColumnLayout {
  width:page.availableWidth;spacing:18
  Label {text:"Global Gaming Experience";font.pixelSize:22;color:redlineAppearance.color("#eee",redlineAppearance.revision);Layout.margins:18}
  Label {text:"Configure Linux launch defaults here, then select a game to apply them. Per-game changes override these defaults.";wrapMode:Text.WordWrap;Layout.fillWidth:true;Layout.leftMargin:18;Layout.rightMargin:18;color:redlineAppearance.color("#999",redlineAppearance.revision)}
  RedlineLaunchControls {store:page.store;globalMode:true;Layout.fillWidth:true;Layout.margins:18;onOpenGames:page.openGames()}
  RedlineSettingsGroup {
   heading:"Graphics Feature Support";Layout.fillWidth:true;Layout.margins:18
   RedlineSettingRow {title:"Super Resolution / Upscaling";currentValue:"Gamescope FSR 1.0 / NIS";description:"Choose a lower render resolution and higher output resolution, then select the filter above. Requires Gamescope."}
   RedlineSettingRow {title:"Virtual Super Resolution";currentValue:"Per-game supersampling";description:"Choose a render resolution higher than the output resolution. This changes the game’s rendering, not the desktop mode."}
   RedlineSettingRow {title:"Integer Scaling";currentValue:"Gamescope integer + nearest";description:"Choose integer scaling and nearest filtering for pixel-art games."}
   RedlineSettingRow {title:"Frame Rate Target";currentValue:"Gamescope FPS limit";description:"Sets a fixed game frame limit. Dynamic Radeon Chill behavior is not implemented."}
   RedlineSettingRow {title:"AMD Fluid Motion Frames / FSR Frame Generation";currentValue:"Not connected";description:"The scaling filters above do not generate frames.";supported:false}
   RedlineSettingRow {title:"Radeon Anti-Lag / Enhanced Sync";currentValue:"Not connected";description:"These Windows driver switches are not exposed by this Linux backend.";supported:false}
  }
 }
}
