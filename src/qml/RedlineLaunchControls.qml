// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
 id:launch
 property var store
 property var game:({})
 property bool globalMode:false
 signal openGames()
 property var tools:gamingTools.available(game.runtime || "native")
 property string command:gamingTools.recipe({gamemode:tools.gamemode && read("launch.gamemode",tools.gamemode),gamescope:tools.gamescope && read("launch.gamescope",false),overlay:tools.overlay && (!tools.gamescope || !read("launch.gamescope",false) || tools.mangoapp) && read("perf.overlay",true),position:read("perf.overlay.position","top-right"),fontSize:read("perf.overlay.font",20),opacity:read("perf.overlay.opacity",50),fpsLimit:read("launch.fps",0),renderSize:read("launch.renderSize","Native"),outputSize:read("launch.outputSize","Native"),scaler:read("launch.scaler","auto"),filter:read("launch.filter","linear")},game.runtime || "native")
 function read(key,value){var r=store.revision;return store.read(key,value)}
 function tr(s){return redlineAppearance.text(s,redlineAppearance.revision)}
 spacing:8
 Label {text:launch.tr(globalMode?"Global launch defaults":"Game launch & Overlay");font.pixelSize:17;color:redlineAppearance.color("#ddd",redlineAppearance.revision)}
 RowLayout {
  Layout.fillWidth:true
  CheckBox {text:"GameMode";enabled:launch.tools.gamemode;checked:launch.tools.gamemode && launch.read("launch.gamemode",launch.tools.gamemode);onToggled:store.write("launch.gamemode",checked)}
  CheckBox {text:"Gamescope";enabled:launch.tools.gamescope;checked:launch.tools.gamescope && launch.read("launch.gamescope",false);onToggled:store.write("launch.gamescope",checked)}
  Label {text:launch.tr(launch.tools.overlay?"MangoHud available":"MangoHud unavailable");color:redlineAppearance.color("#999",redlineAppearance.revision);Layout.fillWidth:true}
  Label {text:gamingTools.gameModeStatus;color:redlineAppearance.color("#999",redlineAppearance.revision);font.pixelSize:11}
 }
 RedlineSettingRow {title:"Gamescope FPS limit";description:"Per-game frame limit. 0 means unlimited.";kind:"choice";choices:["0","30","40","60","90","120","144","165","240"];supported:launch.tools.gamescope && launch.read("launch.gamescope",false);currentValue:String(launch.read("launch.fps",0));onRequested:value=>store.write("launch.fps",Number(value))}
 RedlineSettingRow {title:"Game rendering resolution";description:"Higher than output enables per-game supersampling.";kind:"choice";choices:["Native","1280x720","1600x900","1920x1080","2560x1440","3840x2160"];supported:launch.tools.gamescope && launch.read("launch.gamescope",false);currentValue:launch.read("launch.renderSize","Native");onRequested:value=>store.write("launch.renderSize",value)}
 RedlineSettingRow {title:"Gamescope output resolution";kind:"choice";choices:["Native","1280x720","1600x900","1920x1080","2560x1440","3840x2160"];supported:launch.tools.gamescope && launch.read("launch.gamescope",false);currentValue:launch.read("launch.outputSize","Native");onRequested:value=>store.write("launch.outputSize",value)}
 RedlineSettingRow {title:"Scaling Mode";kind:"choice";choices:["auto","integer","fit","fill","stretch"];supported:launch.tools.gamescope && launch.read("launch.gamescope",false);currentValue:launch.read("launch.scaler","auto");onRequested:value=>store.write("launch.scaler",value)}
 RedlineSettingRow {title:"Upscaling filter";description:"FSR here is Gamescope FSR 1.0, not driver FSR or frame generation.";kind:"choice";choices:["linear","nearest","fsr","nis"];supported:launch.tools.gamescope && launch.read("launch.gamescope",false);currentValue:launch.read("launch.filter","linear");onRequested:value=>store.write("launch.filter",value)}
 Label {visible:game.runtime==="snap" && !launch.tools.gamescope;text:launch.tr("Steam Snap: GameMode and MangoHud are available. Gamescope is not available inside this sandbox.");color:redlineAppearance.color("#999",redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true}
 Label {visible:!launch.globalMode;text:launch.tr("Steam must be closed for automatic connection. Existing options are backed up. Overlay settings apply on the next game launch.");color:redlineAppearance.color("#999",redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true}
 Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:launch.tr(launch.command.length?(launch.globalMode?"Defaults are used when preparing a game. Existing Steam options change only after Apply to Steam.":"Ready to connect selected tools to this game."):"Selected tools are unavailable in this game's runtime.");color:redlineAppearance.color("#999",redlineAppearance.revision)}
 RowLayout {
  RedlineButton {visible:!launch.globalMode;text:"Apply to Steam";accent:true;enabled:launch.command.length>0;onClicked:gamingTools.applyToSteam(game.steamRoot,game.id,launch.command,false)}
  RedlineButton {visible:launch.globalMode;text:"Open game library ›";onClicked:launch.openGames()}
  RedlineButton {visible:!launch.globalMode;text:"Use global defaults";onClicked:store.clearLaunchOverrides()}
  RedlineButton {text:"Copy launch option";enabled:launch.command.length>0;onClicked:gamingTools.copy(launch.command)}
  RedlineButton {visible:!launch.globalMode;text:"Restore Steam options";onClicked:gamingTools.applyToSteam(game.steamRoot,game.id,"",true)}
 }
 Label {text:gamingTools.message;visible:text.length>0;color:redlineAppearance.color("#ddd",redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true}
}
