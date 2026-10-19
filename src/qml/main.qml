// SPDX-License-Identifier: GPL-3.0-or-later
// Based on CoreCtrl main.qml, Copyright 2019 Juan Palacios.
// Modified 2026 for the Redline native fork.
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import "Style.js" as Style
import "Settings.js" as Settings
ApplicationWindow {
 id: appWindow
 title: redlineAppearance.text(("Redline — Linux Graphics Edition"), redlineAppearance.revision)
 width: 1460; height: 920
 minimumWidth: 1180; minimumHeight: 700
 font.family: Style.g_text.family; font.pointSize: Style.g_text.size
 Universal.theme: redlineAppearance.light ? Universal.Light : Universal.Dark; Universal.accent: redlineAppearance.color("#ed003b", redlineAppearance.revision)
 Universal.foreground: redlineAppearance.color("#eeeeee", redlineAppearance.revision); Universal.background: redlineAppearance.color("#101012", redlineAppearance.revision)
 property int section: 0
 property string subSection: ""
 property string selectedGame: ""
 property var sectionTabs: [[],["Chat","Apps"],["Games","Graphics","Advisors"],["Record","Live Stream","Scene Editor","Media","Capture Settings"],["Metrics","Tuning","Metrics Settings"],["Overview"],["System","Display","Audio & Video","Hotkeys","ReLive VR","Preferences"]]
 property var sectionNames: ["Home","AI","Gaming","Record & Stream","Performance","Smart Technology","Settings"]
 property var navigation: [{section:0,sub:"",game:""}]
 property int navigationIndex: 0
 onSectionChanged: subSection = sectionTabs[section][0] || ""
 QtObject {
  id: uiStore
  property int revision: 0
  onRevisionChanged:Qt.callLater(appWindow.syncOverlayPrefs)

  function key(name) {
   if(name.indexOf("launch.")===0 && appWindow.selectedGame)return "games/"+appWindow.selectedGame+"/"+name
   if(name==="game.mode")return "games/"+appWindow.selectedGame+"/mode"
   if(name.indexOf("gaming.graphics.")===0 && appWindow.selectedGame && read("game.mode","Global Experience")==="Custom")return "games/"+appWindow.selectedGame+"/"+name
   return name
  }
  function read(name, fallback) {var rev=revision;try {return JSON.parse(settings.getValue("UiV6/"+key(name),JSON.stringify(fallback)))} catch(e){return fallback}}
  function write(name,value) {settings.setValue("UiV6/"+key(name),JSON.stringify(value));revision++}
  function isFavorite(id) {return read("favorites",[]).indexOf(id)>=0}
  function toggleFavorite(id) {var list=read("favorites",[]);var index=list.indexOf(id);if(index>=0)list.splice(index,1);else list.push(id);write("favorites",list)}
 }
 function syncOverlayPrefs(){nativeDashboard.configureSampling(Number(uiStore.read("perf.interval",1))*1000,Number(uiStore.read("perf.duration",60)));gamingTools.writeOverlay({enabled:uiStore.read("perf.overlay",true),position:uiStore.read("perf.overlay.position","top-right"),fontSize:uiStore.read("perf.overlay.font",20),opacity:uiStore.read("perf.overlay.opacity",50)})}
 Timer {interval:100;running:true;repeat:false;onTriggered:appWindow.syncOverlayPrefs()}
 function applyRoute(route) {section=route.section;subSection=route.sub;selectedGame=route.game;uiStore.revision++;if(section===4 && subSection==="Tuning")Qt.callLater(function(){profileUi.openGlobalProfile()})}
 function navigate(target) {navigateTo(target,sectionTabs[target][0] || "","")}
 function navigateTo(target, sub, game) {
  if(target<0 || target>=sectionTabs.length)return
  if(sectionTabs[target].length && sectionTabs[target].indexOf(sub)<0)sub=sectionTabs[target][0]
  var next={section:target,sub:sub,game:game || ""}
  if(section===next.section && subSection===next.sub && selectedGame===next.game)return
  navigation=navigation.slice(0,navigationIndex+1).concat([next]);navigationIndex=navigation.length-1;applyRoute(next)
 }
 function travel(delta) {var next=navigationIndex+delta;if(next<0 || next>=navigation.length)return;navigationIndex=next;applyRoute(navigation[next])}
 function openTuning() {navigateTo(4,"Tuning","");Qt.callLater(function(){profileUi.openGlobalProfile()})}
 function searchRoutes() {
  var entries=[]
  for(var i=0;i<sectionNames.length;i++) {
   entries.push({label:sectionNames[i],section:i,sub:sectionTabs[i][0] || ""})
   for(var j=0;j<sectionTabs[i].length;j++)entries.push({label:sectionNames[i]+" / "+sectionTabs[i][j],section:i,sub:sectionTabs[i][j]})
  }
  return entries
 }
 function previewTuning() {openTuning()}
 function previewMetrics(){resetAppearance();navigateTo(4,"Metrics","");uiStore.write("perf.metrics.mode","Tracking")
  var before=uiStore.read("perf.visible.cpu",true)
  uiStore.write("perf.visible.cpu",!before)
  var passed=performancePage.shown("cpu")===!before
  uiStore.write("perf.visible.cpu",before)
  console.log("Redline performance visibility smoke: "+(passed?"PASS":"FAIL"))
  nativeDashboard.startLogging()
 }
 function previewOverlay(){nativeDashboard.stopLogging();uiStore.write("perf.metrics.mode","Overlay")}
 function previewFeatures() {navigateTo(3,"Capture Settings","")}
 function previewLibrary() {navigateTo(2,"Games","")}
 function runNavigationSmoke() {
  var oldSection=section, oldSub=subSection, oldGame=selectedGame
  navigateTo(2,"Games",nativeDashboard.games.length?nativeDashboard.games[0].id:"")
  var selected=selectedGame
  navigateTo(6,"Display","");travel(-1)
  var valid=section===2 && selectedGame===selected
  travel(1);valid=valid && section===6 && subSection==="Display"
  navigateTo(2,"Games","");valid=valid && selectedGame===""
  var before=uiStore.read("smoke-preference",false)
  uiStore.write("smoke-preference",!before);valid=valid && uiStore.read("smoke-preference",before)===!before
  uiStore.write("smoke-preference",before)
  applyRoute({section:oldSection,sub:oldSub,game:oldGame});return valid
 }
 component NavIcon: Button {
  property string glyph
  Layout.preferredWidth: 42; Layout.fillHeight: true
  hoverEnabled: true
  icon.source: "icons/" + glyph + ".svg"
  icon.width: 21; icon.height: 21
  icon.color: enabled ? (hovered ? redlineAppearance.color("#ffffff", redlineAppearance.revision) : redlineAppearance.color("#aaaaaf", redlineAppearance.revision)) : redlineAppearance.color("#505054", redlineAppearance.revision)
  background: Rectangle { color: parent.hovered ? redlineAppearance.color("#2c2c30", redlineAppearance.revision) : "transparent" }
  ToolTip.visible: hovered
  ToolTip.text: redlineAppearance.text(text, redlineAppearance.revision)
  display: AbstractButton.IconOnly
 }
 header: ColumnLayout {
  spacing: 0
  Rectangle {
   Layout.fillWidth: true; Layout.preferredHeight: 55; color: redlineAppearance.color("#222225", redlineAppearance.revision)
   RowLayout {
    anchors.fill: parent; spacing: 0
    Rectangle { Layout.preferredWidth: 52; Layout.fillHeight: true; color: redlineAppearance.color("#e90035", redlineAppearance.revision); Label { anchors.centerIn: parent; text: redlineAppearance.text(("R"), redlineAppearance.revision); font.bold: true; font.pixelSize: 29; color: "white" } }
    NavIcon { glyph: "back"; text: "Back"; Layout.preferredWidth: 36; enabled: navigationIndex > 0; onClicked: appWindow.travel(-1) }
    NavIcon { glyph: "forward"; text: "Forward"; Layout.preferredWidth: 36; enabled: navigationIndex < navigation.length - 1; onClicked: appWindow.travel(1) }
    Repeater {
     model: ["Home", "AI", "Gaming", "Record & Stream", "Performance", "Smart Technology"]
     Button {
      required property int index
      required property string modelData
      Layout.fillHeight: true; text: modelData; leftPadding: 16; rightPadding: 16
      hoverEnabled: true
      contentItem: Label { text: redlineAppearance.text((parent.text), redlineAppearance.revision); color: appWindow.section === index || parent.hovered ? redlineAppearance.color("white", redlineAppearance.revision) : redlineAppearance.color("#96969b", redlineAppearance.revision); font.pixelSize: 16; verticalAlignment: Text.AlignVCenter }
      background: Rectangle { color: "transparent"; Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 16; height: 3; visible: appWindow.section === index; color: redlineAppearance.color("#e90035", redlineAppearance.revision) } }
      onClicked: appWindow.navigate(index)
     }
    }
    Item { Layout.fillWidth: true; Layout.minimumWidth: 4 }
    TextField {
     id: searchField
     Layout.preferredWidth: appWindow.width < 1250 ? 105 : 150
     Layout.preferredHeight: 32
     placeholderText: redlineAppearance.text(("Search"), redlineAppearance.revision); font.pixelSize: 12
     background: Rectangle { color: redlineAppearance.color("#252528", redlineAppearance.revision); border.color: searchField.activeFocus ? redlineAppearance.color("#77777d", redlineAppearance.revision) : redlineAppearance.color("#39393d", redlineAppearance.revision) }
     onAccepted: searchDialog.open()
    }
    NavIcon { glyph: "search"; text: "Search games"; Layout.preferredWidth: 32; onClicked: searchDialog.open() }
    NavIcon { glyph: "star"; text: "Favorites"; onClicked: favoritesDialog.open() }
    NavIcon { glyph: "bell"; text: "Notifications"; onClicked: notificationDialog.open() }
    NavIcon { glyph: "settings"; text: "Settings"; onClicked: appWindow.navigate(6) }
    NavIcon { glyph: "menu"; text: "Menu"; onClicked: appMenu.popup() }
   }
   Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: redlineAppearance.color("#333337", redlineAppearance.revision) }
  }
  Rectangle {
   visible: appWindow.sectionTabs[appWindow.section].length>0
   Layout.fillWidth: true; Layout.preferredHeight: visible ? 38 : 0; color: redlineAppearance.color("#1c1c1f", redlineAppearance.revision)
   RowLayout {
    anchors.fill: parent; anchors.leftMargin: 14; spacing: 18
    Repeater {
     model: appWindow.sectionTabs[appWindow.section]
     Button {
      required property string modelData
      Layout.fillHeight: true; text:modelData;leftPadding:2;rightPadding:2
      contentItem: Label {text:redlineAppearance.text((parent.text), redlineAppearance.revision);color:appWindow.subSection===parent.text?redlineAppearance.color("#eeeeee", redlineAppearance.revision):redlineAppearance.color("#99999f", redlineAppearance.revision);verticalAlignment:Text.AlignVCenter;font.pixelSize:13}
      background: Rectangle {color:"transparent";Rectangle{anchors.bottom:parent.bottom;width:parent.width;height:3;color:redlineAppearance.color("#ed003b", redlineAppearance.revision);visible:appWindow.subSection===modelData}}
      onClicked:appWindow.navigateTo(appWindow.section,modelData,"")
     }
    }
    Item {Layout.fillWidth:true}
    Label {visible:appWindow.section===4 && appWindow.subSection==="Tuning";text:redlineAppearance.text((redlineReadOnly?"Read-only preview":"Hardware controls"), redlineAppearance.revision);color:redlineAppearance.color("#999", redlineAppearance.revision);rightPadding:14;font.pixelSize:11}
   }
  }
 }
 Menu {
  id: appMenu
  MenuItem { text: "Settings"; onTriggered: appWindow.navigate(6) }
  MenuItem { text: "About"; onTriggered: aboutDialog.open() }
 }
 property int preferencesRevision: 0
 property bool animationsEnabled: {var rev=preferencesRevision;return settings.getValue("Ui/animations",true)}
 Connections {target:settings;function onSettingChanged(key,value){appWindow.preferencesRevision++}}
 function showSaveToast(message) {if(!settings.getValue("Ui/toastNotifications",true))return;toastMessage.text=message;saveToast.open();toastTimer.restart()}
 Popup {
  id:saveToast;parent:Overlay.overlay;x:appWindow.width-width-20;y:appWindow.height-height-20;padding:16
  closePolicy:Popup.NoAutoClose
  background:Rectangle{color:redlineAppearance.color("#303035", redlineAppearance.revision);border.color:redlineAppearance.color("#ed003b", redlineAppearance.revision);radius:3}
  contentItem:Label{id:toastMessage;color:redlineAppearance.color("#eee", redlineAppearance.revision);font.pixelSize:13}
  enter:Transition{NumberAnimation{property:"opacity";from:0;to:1;duration:appWindow.animationsEnabled?140:0}}
  exit:Transition{NumberAnimation{property:"opacity";from:1;to:0;duration:appWindow.animationsEnabled?140:0}}
 }
 Timer{id:toastTimer;interval:2200;onTriggered:saveToast.close()}
 function previewSettingsDisplay(){navigateTo(6,"Display","")}
 function previewSettingsPreferences(){navigateTo(6,"Preferences","")}
 function previewSystemExpanded(){navigateTo(6,"System","");settingsPage.expandDetails()}
 function previewLightGreek(){settings.setValue("Ui/theme","Light");settings.setValue("Ui/language","Ελληνικά");navigateTo(6,"Preferences","")}
 function previewGaming(){
 resetAppearance();navigateTo(2,"Games","")
 var savedQuery=gameLibrary.query,savedFilter=gameLibrary.favoritesOnly
 gameLibrary.query="__redline_no_match_74a21__"
 var passed=gameLibrary.filteredGames().length===0
 gameLibrary.query="";gameLibrary.favoritesOnly=false
 passed=passed && gameLibrary.filteredGames().length===nativeDashboard.games.length
 if(nativeDashboard.games.length){
  var id=nativeDashboard.games[0].id,wasFavorite=uiStore.isFavorite(id)
  uiStore.toggleFavorite(id);passed=passed && uiStore.isFavorite(id)!==wasFavorite
  uiStore.toggleFavorite(id);passed=passed && uiStore.isFavorite(id)===wasFavorite
 }
 gameLibrary.query=savedQuery;gameLibrary.favoritesOnly=savedFilter
 console.log("Redline gaming filters and favorites smoke: "+(passed?"PASS":"FAIL"))
}
 function previewGameDetails(){if(nativeDashboard.games.length)navigateTo(2,"Games",nativeDashboard.games[0].id)}
 function previewVR(){navigateTo(6,"ReLive VR","")}
 function resetAppearance(){settings.setValue("Ui/theme","Dark");settings.setValue("Ui/language","English")}
 function runAppearanceSmoke(){
  var savedTheme=settings.getValue("Ui/theme","Dark"), savedLanguage=settings.getValue("Ui/language","English")
  settings.setValue("Ui/theme","Light");settings.setValue("Ui/language","Ελληνικά")
  var passed=redlineAppearance.light && redlineAppearance.text("Settings",redlineAppearance.revision)==="Ρυθμίσεις" && redlineAppearance.color("#101012",redlineAppearance.revision)!=="#101012"
  navigateTo(6,"ReLive VR","");passed=passed && subSection==="ReLive VR"
  settings.setValue("Ui/theme",savedTheme);settings.setValue("Ui/language",savedLanguage)
  return passed
 }
 function runSettingsSmoke(){return settingsPage.runPreferenceSmoke()}
 function showDetails(title, message) { detailDialog.title = title; detailText.text = message; detailDialog.open() }
 Dialog {
  id: aboutDialog; objectName: "REDLINE_ABOUT"; title: redlineAppearance.text(("About"), redlineAppearance.revision); anchors.centerIn: parent; modal: true; width: 520; height: 490; padding: 0
  background: Rectangle { color: redlineAppearance.color("#25252b", redlineAppearance.revision); border.color: redlineAppearance.color("#55555c", redlineAppearance.revision) }
  contentItem: About {}
  Overlay.modal: Rectangle { color: redlineAppearance.color("#aa000000", redlineAppearance.revision) }
  header: Rectangle { height: 56; color: redlineAppearance.color("#25252b", redlineAppearance.revision); Label { anchors.left: parent.left; anchors.leftMargin: 26; anchors.verticalCenter: parent.verticalCenter; text: redlineAppearance.text(("About"), redlineAppearance.revision); font.pixelSize: 23; color: redlineAppearance.color("#eee", redlineAppearance.revision) } ToolButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "×"; onClicked: aboutDialog.close() } }
  footer: Rectangle { height: 64; color: redlineAppearance.color("#25252b", redlineAppearance.revision); RedlineButton { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 18; text: "Close"; accent: true; onClicked: aboutDialog.close() } }
 }
 Dialog {
  id: notificationDialog; width:520; title: redlineAppearance.text(("Notifications"), redlineAppearance.revision); anchors.centerIn: parent; modal: true; standardButtons: Dialog.Close
  Label { width:parent.width;wrapMode:Text.WordWrap; text: redlineAppearance.text((redlineReadOnly ? "Read-only preview. Hardware changes are disabled." : "No new notifications."), redlineAppearance.revision); color: redlineAppearance.color("#bbb", redlineAppearance.revision) }
 }
 Dialog {
  id: detailDialog; anchors.centerIn: parent; modal: true; standardButtons: Dialog.Close; width: 480
  background: Rectangle { color: redlineAppearance.color("#25252b", redlineAppearance.revision); border.color: redlineAppearance.color("#55555c", redlineAppearance.revision) }
  Label { id: detailText; width: parent.width; wrapMode: Text.WordWrap; color: redlineAppearance.color("#bbb", redlineAppearance.revision); font.pixelSize: 14 }
 }
 Dialog {
  id: favoritesDialog; title: redlineAppearance.text(("Favorites"), redlineAppearance.revision); anchors.centerIn: parent; modal: true; standardButtons: Dialog.Ok
  ColumnLayout {
   Label { text: redlineAppearance.text(("Favorite games"), redlineAppearance.revision); color:redlineAppearance.color("#ddd", redlineAppearance.revision) }
   Repeater { model:nativeDashboard.games
    RedlineButton { required property var modelData; visible:{var rev=uiStore.revision;return uiStore.isFavorite(modelData.id)}
text:modelData.name;onClicked:{favoritesDialog.close();appWindow.navigateTo(2,"Games",modelData.id)} }
   }
   Label {text:redlineAppearance.text(("Use ☆ Favorite inside a game to add it here."), redlineAppearance.revision);color:redlineAppearance.color("#999", redlineAppearance.revision)}
  }
 }
 Dialog {
  id: searchDialog; title: redlineAppearance.text(("Search"), redlineAppearance.revision); anchors.centerIn: parent; modal: true; standardButtons: Dialog.Close; width: 480; height: 560
  ScrollView {
   anchors.fill: parent; clip:true; contentWidth:availableWidth
  ColumnLayout {
   width: parent.width
   Repeater {
    model: nativeDashboard.games
    Button {
     required property var modelData
     Layout.fillWidth: true
     visible: searchField.text.length === 0 || modelData.name.toLowerCase().indexOf(searchField.text.toLowerCase()) >= 0
     text: modelData.name
     onClicked: { appWindow.navigateTo(2,"Games",modelData.id); searchDialog.close() }
    }
   }
   Repeater {
    model:appWindow.searchRoutes()
    RedlineButton {required property var modelData;visible:searchField.text.length===0 || modelData.label.toLowerCase().indexOf(searchField.text.toLowerCase())>=0;text:modelData.label;onClicked:{searchDialog.close();appWindow.navigateTo(modelData.section,modelData.sub,"")}}
   }
   Label { text: redlineAppearance.text(("Installed games and pages matching: " + searchField.text), redlineAppearance.revision); color: redlineAppearance.color("#999", redlineAppearance.revision); wrapMode: Text.Wrap; Layout.fillWidth: true }
  }
  }
 }
 StackLayout {
  anchors.fill: parent
  currentIndex: appWindow.section===0?0:appWindow.section===2 && appWindow.subSection==="Games"?1:appWindow.section===6 && ["System","Display","ReLive VR","Preferences"].indexOf(appWindow.subSection)>=0?2:appWindow.section===4 && appWindow.subSection==="Metrics"?3:appWindow.section===4 && appWindow.subSection==="Tuning"?5:4
  RedlineHome {
   onShowDetails:(title,message)=>appWindow.showDetails(title,message)
   onOpenSettings:appWindow.navigate(6)
   onOpenProfiles:appWindow.openTuning()
   onOpenPerformance:appWindow.navigateTo(4,"Metrics","")
   onOpenGame:id=>appWindow.navigateTo(2,"Games",id)
  }
  RedlineLibrary {id:gameLibrary;onOpenGlobalDisplay:appWindow.navigateTo(6,"Display","");gameId:appWindow.selectedGame;store:uiStore;onOpenGame:id=>appWindow.navigateTo(2,"Games",id);onOpenHardware:appWindow.openTuning()}
  System {id:settingsPage;subpage:appWindow.subSection;onShowAbout:aboutDialog.open();onInformation:(title,message)=>appWindow.showDetails(title,message);onPreferenceSaved:message=>appWindow.showSaveToast(message)}
  RedlinePerformance {id:performancePage;onOpenGaming:appWindow.navigateTo(2,"Games","");store:uiStore;onOpenTuning:appWindow.openTuning()}
  RedlineFeaturePage {
   pageKey:appWindow.sectionNames[appWindow.section]+"/"+(appWindow.subSection==="Capture Settings" || appWindow.subSection==="Metrics Settings"?"Settings":appWindow.subSection)
   store:uiStore;onOpenHardware:appWindow.openTuning();onDetails:(title,message)=>appWindow.showDetails(title,message)
  }
  Profiles {id:profileUi}
 }
 onClosing: close => { if (!systemTray.isAvailable() || !systemTray.isVisible()) Qt.quit() }
}
