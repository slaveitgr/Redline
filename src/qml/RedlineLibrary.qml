// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "FeatureCatalog.js" as Catalog
Item {
 id: library
 property string gameId: ""
 property var store
 property string query: ""
 property bool favoritesOnly: false
 property bool alphabetical: true
 signal openGame(string id)
 signal openHardware()
 signal openGlobalDisplay()
 function tr(s) {return redlineAppearance.text(s,redlineAppearance.revision)}
 function shade(s) {return redlineAppearance.color(s,redlineAppearance.revision)}
 function game() {for(var i=0;i<nativeDashboard.games.length;i++)if(nativeDashboard.games[i].id===gameId)return nativeDashboard.games[i];return {name:"",id:"",art:""}}
 function filteredGames() {
  var revision=store.revision
  var result=nativeDashboard.games.filter(function(g){return g.name.toLowerCase().indexOf(query.toLowerCase())>=0 && (!favoritesOnly || store.isFavorite(g.id))})
  if(alphabetical)result.sort(function(a,b){return a.name.localeCompare(b.name)})
  return result
 }
 ColumnLayout {
  anchors.fill:parent;anchors.margins:18;spacing:16
  RowLayout {
   Layout.fillWidth:true
   RedlineButton {visible:!!library.gameId;text:"‹ All Games";onClicked:library.openGame("")}
   Label {text:library.tr(library.gameId?library.game().name:"Library")+(!library.gameId?" ("+library.filteredGames().length+")":"");font.pixelSize:19;color:library.shade("#ddd");Layout.fillWidth:true}
   TextField {visible:!library.gameId;placeholderText:library.tr("Filter installed games");Layout.preferredWidth:220;onTextChanged:library.query=text}
   RedlineButton {visible:!library.gameId;text:library.favoritesOnly?"★ Favorites":"☆ Favorites";accent:library.favoritesOnly;onClicked:library.favoritesOnly=!library.favoritesOnly}
   RedlineButton {visible:!library.gameId;text:library.alphabetical?"A → Z":"Steam order";onClicked:library.alphabetical=!library.alphabetical}
   RedlineButton {visible:!!library.gameId;text:{var rev=store.revision;return store.isFavorite(library.gameId)?"★ Saved":"☆ Favorite"} onClicked:store.toggleFavorite(library.gameId)}
   RedlineButton {visible:!!library.gameId;text:"Play";accent:true;onClicked:nativeDashboard.launchGame(library.gameId)}
  }
  ScrollView {
   visible:!library.gameId;Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth;clip:true
   ColumnLayout {
    width:parent.width;spacing:20
    Flow {
     Layout.fillWidth:true;spacing:10
     Repeater {
      model:library.filteredGames()
      Rectangle {
       id:tile
       required property var modelData
       width:Math.floor((parent.width-10*(Math.max(1,Math.floor(parent.width/145))-1))/Math.max(1,Math.floor(parent.width/145)));height:214
       color:library.shade(tileHover.hovered?"#303034":"#252528")
       HoverHandler {id:tileHover}
       ColumnLayout {
        anchors.fill:parent;spacing:0
        Item {
         Layout.fillWidth:true;Layout.preferredHeight:101
         Image {id:art;anchors.centerIn:parent;width:parent.width-30;height:70;source:tile.modelData.art;fillMode:Image.PreserveAspectFit}
         Label {visible:art.status!==Image.Ready;anchors.centerIn:parent;text:tile.modelData.name.substring(0,1);font.pixelSize:36;color:library.shade("#999")}
        }
        Label {text:tile.modelData.name;Layout.fillWidth:true;Layout.leftMargin:8;Layout.rightMargin:8;Layout.preferredHeight:42;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight;color:library.shade("#ddd");font.pixelSize:12}
        RowLayout {
         Layout.fillWidth:true
         Repeater {model:["Play Total","Avg. FPS"];ColumnLayout {required property string modelData;Layout.fillWidth:true;spacing:3;Label{text:library.tr(modelData);font.pixelSize:10;color:library.shade("#999");Layout.alignment:Qt.AlignHCenter}Label{text:"—";color:library.shade("#bbb");Layout.alignment:Qt.AlignHCenter}}}
        }
        Item {Layout.preferredHeight:10}
       }
       MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:library.openGame(tile.modelData.id)}
       ToolButton {anchors.left:parent.left;anchors.top:parent.top;width:30;height:30;Accessible.name:library.tr("Favorite")+" "+tile.modelData.name;text:{var rev=store.revision;return store.isFavorite(tile.modelData.id)?"★":"☆"} onClicked:store.toggleFavorite(tile.modelData.id)}
      }
     }
    }
    Label {visible:library.filteredGames().length===0;text:library.tr(nativeDashboard.games.length?"No games match your filters.":"No installed Steam games detected.");color:library.shade("#999");Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter;Layout.topMargin:60}
    Label {text:library.tr("Play time and FPS are not tracked yet.");color:library.shade("#888");font.pixelSize:11;Layout.fillWidth:true}
   }
  }
  ScrollView {
   visible:!!library.gameId;Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth;clip:true
   ColumnLayout {
    width:parent.width;spacing:18
    RedlineLaunchControls {Layout.fillWidth:true;store:library.store;game:library.game()}
    Label {text:library.tr("Launch settings above override global defaults for this game. Driver-level GPU / CPU tuning is available in the integrated controls.");color:library.shade("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true}
    RowLayout {
     Layout.fillWidth:true;spacing:24
     ColumnLayout {
      Layout.fillWidth:true;Layout.preferredWidth:1;Layout.alignment:Qt.AlignTop;spacing:8
      RowLayout {Layout.fillWidth:true;Label{text:library.tr("Graphics");color:library.shade("#ddd");Layout.fillWidth:true;font.pixelSize:17}RedlineButton{text:"GPU / CPU controls ›";onClicked:library.openHardware()}}
      RedlineSettingRow {title:"Gaming Experience";kind:"info";currentValue:"Per-game launch settings";description:"Global defaults are inherited until overridden above"}
      Repeater {
       model:(Catalog.pages["Gaming/Graphics"] || []).slice(1)
       RedlineSettingRow {required property var modelData;title:modelData.label;description:modelData.description || "";kind:"switch";supported:false;reason:library.tr("This driver feature is not exposed by the current Linux backend.")}
      }
     }
     ColumnLayout {
      Layout.fillWidth:true;Layout.preferredWidth:1;Layout.alignment:Qt.AlignTop;spacing:8
      RowLayout {Layout.fillWidth:true;Label{text:library.tr("Display");font.pixelSize:17;color:library.shade("#ddd")}Item{Layout.fillWidth:true}RedlineButton{text:"Global Display ›";onClicked:library.openGlobalDisplay()}}
      RedlineSettingRow {title:"Display settings";currentValue:"Global settings";description:"Display overrides per game are not available."}
      Repeater {
       model:["AMD FreeSync","Scaling Mode","Integer Scaling","Custom Color","Display Color Enhancement","Color Deficiency Correction"]
       RedlineSettingRow {required property string modelData;title:modelData;kind:"info";currentValue:"Unavailable";supported:false}
      }
     }
    }
   }
  }
 }
}
