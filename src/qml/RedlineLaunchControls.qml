// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:launch
 property var store
 property var game:({})
 property var tools:gamingTools.available(game.runtime || "native")
 property string command:gamingTools.recipe({gamemode:read("launch.gamemode",tools.gamemode),gamescope:read("launch.gamescope",false),overlay:read("perf.overlay",true),position:read("perf.overlay.position","top-right"),fontSize:read("perf.overlay.font",20),opacity:read("perf.overlay.opacity",50),fpsLimit:read("launch.fps",0)},game.runtime || "native")
 function read(key,value){var r=store.revision;return store.read(key,value)}
 function tr(s){return redlineAppearance.text(s,redlineAppearance.revision)}
 spacing:8
 Label {text:launch.tr("Game launch & Overlay");font.pixelSize:17;color:redlineAppearance.color("#ddd",redlineAppearance.revision)}
 RowLayout {
  Layout.fillWidth:true
  CheckBox {text:"GameMode";enabled:launch.tools.gamemode;checked:launch.read("launch.gamemode",launch.tools.gamemode);onToggled:store.write("launch.gamemode",checked)}
  CheckBox {text:"Gamescope";enabled:launch.tools.gamescope;checked:launch.read("launch.gamescope",false);onToggled:store.write("launch.gamescope",checked)}
  Label {text:launch.tr(launch.tools.overlay?"MangoHud available":"MangoHud unavailable");color:redlineAppearance.color("#999",redlineAppearance.revision);Layout.fillWidth:true}
  Label {text:gamingTools.gameModeStatus;color:redlineAppearance.color("#999",redlineAppearance.revision);font.pixelSize:11}
 }
 Label {visible:game.runtime==="snap" && !launch.tools.gamescope;text:launch.tr("Steam Snap: GameMode and MangoHud are available. Gamescope is not available inside this sandbox.");color:redlineAppearance.color("#999",redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true}
 Label {text:launch.tr("Steam must be closed for automatic connection. Existing options are backed up. Overlay settings apply on the next game launch.");color:redlineAppearance.color("#999",redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true}
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:launch.tr(launch.command.length?"Ready to connect selected tools to this game.":"Selected tools are unavailable in this game's runtime.");color:redlineAppearance.color("#999",redlineAppearance.revision)}
 RowLayout {
  RedlineButton {text:"Apply to Steam";accent:true;enabled:launch.command.length>0;onClicked:gamingTools.applyToSteam(game.steamRoot,game.id,launch.command,false)}
  RedlineButton {text:"Copy launch option";enabled:launch.command.length>0;onClicked:gamingTools.copy(launch.command)}
  RedlineButton {text:"Restore Steam options";onClicked:gamingTools.applyToSteam(game.steamRoot,game.id,"",true)}
 }
 Label {text:gamingTools.message;visible:text.length>0;color:redlineAppearance.color("#ddd",redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true}
}
