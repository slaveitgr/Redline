// SPDX-License-Identifier: GPL-3.0-or-later
// Based on CoreCtrl main.qml, Copyright 2019 Juan Palacios.
// Modified 2026 for the Redline native fork.
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import "Style.js" as Style
import "Settings.js" as Settings
import "RedlineDesign.js" as Design
ApplicationWindow {
 id: appWindow
 title: redlineAppearance.text(redlineReadOnly?"Redline — UI Preview":"Redline — Linux Graphics Edition", redlineAppearance.revision)
 width: 1460; height: 920
 minimumWidth: 1180; minimumHeight: 700
 font.family: "Sans Serif"; font.pixelSize: 14
 Universal.theme: redlineAppearance.light ? Universal.Light : Universal.Dark; Universal.accent: redlineAppearance.color("#ed003b", redlineAppearance.revision)
 Universal.foreground: redlineAppearance.color("#eeeeee", redlineAppearance.revision); Universal.background: redlineAppearance.color("#101012", redlineAppearance.revision)
 property int section: 0
 property string subSection: ""
 property string selectedGame: ""
 property var sectionTabs: [[],["Chat","Apps"],["Games","Graphics","Advisors"],["Record","Live Stream","Scene Editor","Media","Settings"],["Metrics","Tuning","Settings"],["Overview"],["System","Display","Audio & Video","Hotkeys","ReLive VR","Preferences"],[]]
 property var sectionNames: ["Home","AI","Gaming","Record & Stream","Performance","Smart Technology","Settings","Notifications"]
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
  function globalRead(name,fallback){try{var value=JSON.parse(settings.getValue("UiV6/"+name,JSON.stringify(fallback)));return value===null?fallback:value}catch(e){return fallback}}
  function read(name, fallback) {var rev=revision;if(name.indexOf("launch.")===0 && appWindow.selectedGame)fallback=globalRead(name,fallback);try {var value=JSON.parse(settings.getValue("UiV6/"+key(name),JSON.stringify(fallback)));return value===null?fallback:value} catch(e){return fallback}}
  function clearLaunchOverrides(){if(!appWindow.selectedGame)return;var keys=["launch.gamemode","launch.gamescope","launch.fps","launch.renderSize","launch.outputSize","launch.scaler","launch.filter"];for(var i=0;i<keys.length;i++)settings.setValue("UiV6/"+key(keys[i]),"null");revision++}
  function write(name,value) {settings.setValue("UiV6/"+key(name),JSON.stringify(value));revision++}
  function isFavorite(id) {return read("favorites",[]).indexOf(id)>=0}
  function toggleFavorite(id) {var list=read("favorites",[]);var index=list.indexOf(id);if(index>=0)list.splice(index,1);else list.push(id);write("favorites",list)}
 }
 Connections {target:settingsSnapshots;function onApplied(){uiStore.revision++}}
 function syncOverlayPrefs(){nativeDashboard.configureSampling(Number(uiStore.read("perf.interval",1))*1000,Number(uiStore.read("perf.duration",60)));gamingTools.writeOverlay({enabled:uiStore.read("perf.overlay",true),position:uiStore.read("perf.overlay.position","top-right"),fontSize:uiStore.read("perf.overlay.font",20),opacity:uiStore.read("perf.overlay.opacity",50),metrics:performancePage.overlayMetrics(),fpsLimit:uiStore.read("perf.overlay.fpsLimit",0),horizontal:uiStore.read("perf.overlay.horizontal",false),hotkey:uiStore.read("perf.overlay.hotkey","Shift_R+F12")})}
 Timer {interval:100;running:true;repeat:false;onTriggered:appWindow.syncOverlayPrefs()}
 function applyRoute(route) {section=route.section;subSection=route.sub;selectedGame=route.game;uiStore.revision++;if(section===4 && subSection==="Tuning")Qt.callLater(function(){profileUi.openGlobalProfile()})}
 function navigate(target) {navigateTo(target,sectionTabs[target][0] || "","")}
 function navigateTo(target, sub, game) {
  if(sub==="Capture Settings" || sub==="Metrics Settings")sub="Settings"
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
 function matchesSearch(label){var revision=redlineAppearance.revision;var query=searchField.text.trim().toLocaleLowerCase();return !query || label.toLocaleLowerCase().indexOf(query)>=0 || redlineAppearance.text(label,revision).toLocaleLowerCase().indexOf(query)>=0}
 function previewTuning() {openTuning()}
 function previewMetrics(){resetAppearance();navigateTo(4,"Metrics","");uiStore.write("perf.metrics.mode","Tracking")
  var before=uiStore.read("perf.visible.cpu",true)
  uiStore.write("perf.visible.cpu",!before)
  var passed=performancePage.shown("cpu")===!before
  uiStore.write("perf.visible.cpu",before)
  console.log("Redline performance visibility smoke: "+(passed?"PASS":"FAIL"))
  nativeDashboard.startLogging()
 }
 function previewOverlay(){
  nativeDashboard.stopLogging();uiStore.write("perf.metrics.mode","Overlay")
  var saved=performancePage.overlayMetrics();var passed=true
  performancePage.setOverlayProfile("Compact");passed=performancePage.overlayProfile()==="Compact" && !performancePage.overlayMetrics().gpu_temp
  performancePage.setOverlayProfile("Detailed");passed=passed && performancePage.overlayMetrics().frame_timing
  uiStore.write("perf.overlay.metric.gpu_fan",false);passed=passed && performancePage.overlayProfile()==="Custom"
  for(var key in saved)uiStore.write("perf.overlay.metric."+key,saved[key])
  syncOverlayPrefs()
  console.log("Redline overlay profile and metric controls smoke: "+(passed?"PASS":"FAIL"))
 }

 function previewFeatures() {navigateTo(3,"Settings","")}
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
 RedlineNotificationsModel {id:notificationCenter}
 property string lastGpuError:""
 Connections {target:redlineGpu;function onChanged(){if(redlineGpu.error && redlineGpu.error!==appWindow.lastGpuError){appWindow.lastGpuError=redlineGpu.error;notificationCenter.add("gpu:"+redlineGpu.error,"GPU backend",redlineGpu.error,"error")}}}
 Timer {interval:0;running:true;repeat:false;onTriggered:{if(redlineReadOnly)notificationCenter.add("preview","Read-only preview","Hardware changes are disabled in this development preview.","information")}}
 Shortcut {sequence:"Alt+Left";onActivated:appWindow.travel(-1)}
 Shortcut {sequence:"Alt+Right";onActivated:appWindow.travel(1)}
 Shortcut {sequence:"Ctrl+F";onActivated:{if(searchField.visible){searchField.forceActiveFocus();searchField.selectAll()}else searchDialog.open()}}
 header:ColumnLayout {
  spacing:0
  Rectangle {
   objectName:"REDLINE_NAVIGATION_BAR"
   Layout.fillWidth:true;Layout.preferredHeight:Design.navigationHeight
   color:redlineAppearance.color(Design.navigationSurface,redlineAppearance.revision)
   RowLayout {
    anchors.fill:parent;spacing:0
    Button {
     objectName:"REDLINE_HOME_LOGO";Layout.preferredWidth:64;Layout.fillHeight:true
     Accessible.name:redlineAppearance.text("Home",redlineAppearance.revision)
     background:Rectangle{color:"#e90035"}
     contentItem:Image{source:"qrc:/images/AppIcon";fillMode:Image.PreserveAspectFit;sourceSize.width:64;sourceSize.height:64}
     padding:6;onClicked:appWindow.navigate(0)
    }
    RedlineIconButton {objectName:"REDLINE_BACK";glyph:"back";imageSize:24;text:"Back";Layout.preferredWidth:48;Layout.fillHeight:true;enabled:navigationIndex>0;onClicked:appWindow.travel(-1)}
    RedlineIconButton {objectName:"REDLINE_FORWARD";glyph:"forward";imageSize:24;text:"Forward";Layout.preferredWidth:48;Layout.fillHeight:true;enabled:navigationIndex<navigation.length-1;onClicked:appWindow.travel(1)}
    Flickable {
     id:primaryNavigation;Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumWidth:240
     contentWidth:primaryNavigationRow.width;contentHeight:height;clip:true;boundsBehavior:Flickable.StopAtBounds;flickableDirection:Flickable.HorizontalFlick
     Row {
      id:primaryNavigationRow;height:primaryNavigation.height
      Repeater {
       id:primaryButtons;model:appWindow.sectionNames.slice(0,6)
       RedlineNavButton {required property int index;required property string modelData;height:parent.height;objectName:"REDLINE_NAV_"+index;compact:appWindow.width<1380;text:modelData;selected:appWindow.section===index;onClicked:appWindow.navigate(index)}
      }
     }
     ScrollBar.horizontal:ScrollBar{policy:primaryNavigation.contentWidth>primaryNavigation.width?ScrollBar.AsNeeded:ScrollBar.AlwaysOff;height:3}
     function revealSelection(){if(appWindow.section<0 || appWindow.section>=6)return;var item=primaryButtons.itemAt(appWindow.section);if(!item)return;if(item.x<contentX)contentX=item.x;else if(item.x+item.width>contentX+width)contentX=Math.max(0,item.x+item.width-width)}
     onWidthChanged:Qt.callLater(revealSelection)
     Connections {target:appWindow;function onSectionChanged(){Qt.callLater(primaryNavigation.revealSelection)}}
    }
    TextField {
     id:searchField;objectName:"REDLINE_SEARCH";visible:appWindow.width>=1380;Layout.preferredWidth:180;Layout.preferredHeight:36
     rightPadding:36;leftPadding:12;font.pixelSize:12;placeholderText:redlineAppearance.text("Search",redlineAppearance.revision)
     Accessible.name:redlineAppearance.text("Search",redlineAppearance.revision)
     background:Rectangle{color:"transparent";border.width:2;border.color:redlineAppearance.color(searchField.activeFocus?"#808080":"#404040",redlineAppearance.revision)}
     onAccepted:searchDialog.open()
     RedlineIconButton {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:34;height:34;imageSize:22;glyph:"search";text:"Search";onClicked:searchDialog.open()}
    }
    RedlineIconButton {visible:!searchField.visible;glyph:"search";text:"Search";imageSize:24;Layout.preferredWidth:40;Layout.fillHeight:true;onClicked:searchDialog.open()}
    RedlineIconButton {objectName:"REDLINE_FEEDBACK";glyph:"star";text:"Feedback";Layout.fillHeight:true;onClicked:feedbackDialog.open()}
    RedlineIconButton {objectName:"REDLINE_NOTIFICATIONS";glyph:"bell";text:"Notifications";Layout.fillHeight:true;checked:appWindow.section===7;badgeCount:notificationCenter.unreadCount;onClicked:appWindow.navigate(7)}
    RedlineIconButton {objectName:"REDLINE_SETTINGS";glyph:"settings";text:"Settings";Layout.fillHeight:true;checked:appWindow.section===6;onClicked:appWindow.navigate(6)}
    RedlineIconButton {objectName:"REDLINE_SIDEBAR";glyph:"menu";text:"Navigation sidebar";Layout.fillHeight:true;checked:navigationDrawer.opened;onClicked:navigationDrawer.opened?navigationDrawer.close():navigationDrawer.open()}
   }
  }
  Rectangle {
   visible:appWindow.sectionTabs[appWindow.section].length>0
   Layout.fillWidth:true;Layout.preferredHeight:visible?Design.subnavigationHeight:0
   color:redlineAppearance.color("#202020",redlineAppearance.revision)
   RowLayout {
    anchors.fill:parent;anchors.leftMargin:0;spacing:0
    Repeater {
     model:appWindow.sectionTabs[appWindow.section]
     RedlineNavButton {required property string modelData;secondary:true;Layout.fillHeight:true;text:modelData;selected:appWindow.subSection===modelData;onClicked:appWindow.navigateTo(appWindow.section,modelData,"")}
    }
    Item {Layout.fillWidth:true}
    Label {visible:appWindow.section===4 && appWindow.subSection==="Tuning";text:redlineAppearance.text(redlineReadOnly?"Read-only preview":"Hardware controls",redlineAppearance.revision);color:redlineAppearance.color("#969696",redlineAppearance.revision);rightPadding:16;font.pixelSize:11}
   }
  }
 }
 Drawer {
  id:navigationDrawer;objectName:"REDLINE_NAVIGATION_SIDEBAR";parent:Overlay.overlay;edge:Qt.RightEdge
  width:300;y:appWindow.header.height;height:appWindow.height-y;modal:false;dim:false
  background:Rectangle{color:redlineAppearance.color("#202020",redlineAppearance.revision);border.color:redlineAppearance.color("#404040",redlineAppearance.revision)}
  ScrollView {
   anchors.fill:parent;contentWidth:availableWidth;clip:true
   ColumnLayout {
    width:parent.width;spacing:0
    Label {text:"REDLINE";font.pixelSize:18;font.bold:true;color:redlineAppearance.color("#eeeeee",redlineAppearance.revision);Layout.margins:20}
    Repeater {model:appWindow.sectionNames
     ItemDelegate {id:sidebarEntry;required property int index;required property string modelData;Layout.fillWidth:true;text:redlineAppearance.text(modelData,redlineAppearance.revision);highlighted:appWindow.section===index;contentItem:Label{text:sidebarEntry.text;color:sidebarEntry.highlighted?"white":redlineAppearance.color("#dddddd",redlineAppearance.revision);verticalAlignment:Text.AlignVCenter}
      onClicked:{appWindow.navigate(index);navigationDrawer.close()}}
    }
    Rectangle{Layout.fillWidth:true;Layout.preferredHeight:1;color:redlineAppearance.color("#404040",redlineAppearance.revision)}
    ItemDelegate {Layout.fillWidth:true;text:redlineAppearance.text("Favorite games",redlineAppearance.revision);onClicked:{navigationDrawer.close();favoritesDialog.open()}}
    ItemDelegate {Layout.fillWidth:true;text:redlineAppearance.text("About",redlineAppearance.revision);onClicked:{navigationDrawer.close();aboutDialog.open()}}
   }
  }
 }
 Dialog {
  id:feedbackDialog;title:redlineAppearance.text("Feedback",redlineAppearance.revision);anchors.centerIn:parent;modal:true;width:480;standardButtons:Dialog.Close
  ColumnLayout {
   width:parent.width;spacing:16
   Label {text:redlineAppearance.text("Report a problem or suggest a feature for Redline.",redlineAppearance.revision);wrapMode:Text.WordWrap;Layout.fillWidth:true}
   RedlineButton {text:"Open GitHub issues";accent:true;onClicked:{nativeDashboard.openProjectPage("issues");feedbackDialog.close()}}
  }
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
 function previewSettingsDisplay(){width=1460;height=920;navigateTo(6,"Display","")}
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
 function runShellSmoke(){
  var oldRoute={section:section,sub:subSection,game:selectedGame};var count=notificationCenter.unreadCount
  var oldQuery=searchField.text;var oldLanguage=settings.getValue("Ui/language","English")
  var valid=sectionTabs[3][4]==="Settings" && sectionTabs[4][2]==="Settings"
  searchField.text="Performance";valid=valid && matchesSearch("Performance")
  settings.setValue("Ui/language","Ελληνικά");searchField.text="Απόδοση";valid=valid && matchesSearch("Performance")
  settings.setValue("Ui/language",oldLanguage);searchField.text=oldQuery
  notificationCenter.add("shell-smoke","Shell test","Temporary test event","information")
  valid=valid && !notificationCenter.add("shell-smoke","Shell test","Duplicate event","information")
  valid=valid && notificationCenter.unreadCount===count+1
  navigate(7);valid=valid && section===7
  notificationCenter.markRead(0);valid=valid && notificationCenter.unreadCount===count
  notificationCenter.remove(0);navigationDrawer.open();valid=valid && navigationDrawer.visible
  navigationDrawer.close();applyRoute(oldRoute)
  console.log("Redline shell navigation and notification lifecycle smoke: "+(valid?"PASS":"FAIL"));return valid
 }
 function previewAIChat(){navigationDrawer.close();navigateTo(1,"Chat","")}
 function previewAIApps(){navigateTo(1,"Apps","")}
 function runAIHomeSmoke(){
  var saved={section:section,sub:subSection,game:selectedGame}
  previewAIChat();aiPage.draft("Explain GameMode and Gamescope")
  var passed=section===1 && subSection==="Chat" && !localAssistant.busy && !aiPage.includeSensors
  previewAIApps();passed=passed && subSection==="Apps"
  navigate(0);passed=passed && section===0
  aiPage.draft("");applyRoute(saved)
  console.log("Redline AI and Home navigation smoke: "+(passed?"PASS":"FAIL"));return passed
 }
 function previewVRInstall(){navigateTo(6,"ReLive VR","");settingsPage.showVRInstall()}
 function previewCaptureSettings(){settingsPage.closePreviewDialogs();resetAppearance();navigateTo(3,"Settings","")}
 function previewGraphics(){navigateTo(2,"Graphics","")}
 function previewHotkeys(){navigateTo(6,"Hotkeys","")}
 function runNewFeaturesSmoke(){
  var passed=captureBackend.codecs.length>0 && shortcutSupport.canonical("Ctrl+Shift+R")==="Ctrl+Shift+R" && shortcutSupport.canonical("plain text")===""
  var savedGame=selectedGame;var old=uiStore.globalRead("launch.fps",0)
  selectedGame="";uiStore.write("launch.fps",90);selectedGame="__redline_scope_test__"
  passed=passed && uiStore.read("launch.fps",0)===90
  uiStore.write("launch.fps",60);passed=passed && uiStore.read("launch.fps",0)===60 && uiStore.globalRead("launch.fps",0)===90
  uiStore.clearLaunchOverrides();passed=passed && uiStore.read("launch.fps",0)===90
  selectedGame="";uiStore.write("launch.fps",old);selectedGame=savedGame
  console.log("Redline recording capabilities, shortcut and game scope smoke: "+(passed?"PASS":"FAIL"));return passed
 }
 function previewSnapshots(){navigateTo(6,"System","");settingsPage.showSnapshots()}
 function previewNotifications(){navigate(7)}
 function previewSidebar(){navigationDrawer.open()}
 function showDetails(title, message) { detailDialog.title = title; detailText.text = message; detailDialog.open() }
 Dialog {
  id: aboutDialog; objectName: "REDLINE_ABOUT"; title: redlineAppearance.text(("About"), redlineAppearance.revision); anchors.centerIn: parent; modal: true; width: 560; height: 560; padding: 0
  background: Rectangle { color: redlineAppearance.color("#25252b", redlineAppearance.revision); border.color: redlineAppearance.color("#55555c", redlineAppearance.revision) }
  contentItem: About {}
  Overlay.modal: Rectangle { color: redlineAppearance.color("#aa000000", redlineAppearance.revision) }
  header: Rectangle { height: 56; color: redlineAppearance.color("#25252b", redlineAppearance.revision); Label { anchors.left: parent.left; anchors.leftMargin: 26; anchors.verticalCenter: parent.verticalCenter; text: redlineAppearance.text(("About"), redlineAppearance.revision); font.pixelSize: 23; color: redlineAppearance.color("#eee", redlineAppearance.revision) } ToolButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "×"; onClicked: aboutDialog.close() } }
  footer: Rectangle { height: 64; color: redlineAppearance.color("#25252b", redlineAppearance.revision); RedlineButton { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 18; text: "Close"; accent: true; onClicked: aboutDialog.close() } }
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
  onOpened:{dialogSearchField.text=searchField.text;dialogSearchField.forceActiveFocus();dialogSearchField.selectAll()}
  ColumnLayout {
   anchors.fill:parent
   TextField {id:dialogSearchField;Layout.fillWidth:true;placeholderText:redlineAppearance.text("Search",redlineAppearance.revision);onTextEdited:searchField.text=text}
   ScrollView {
   Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth
  ColumnLayout {
   width: parent.width
   Repeater {
    model: nativeDashboard.games
    Button {
     required property var modelData
     Layout.fillWidth: true
     visible:appWindow.matchesSearch(modelData.name)
     text: modelData.name
     onClicked: { appWindow.navigateTo(2,"Games",modelData.id); searchDialog.close() }
    }
   }
   Repeater {
    model:appWindow.searchRoutes()
    RedlineButton {required property var modelData;visible:appWindow.matchesSearch(modelData.label);text:modelData.label;onClicked:{searchDialog.close();appWindow.navigateTo(modelData.section,modelData.sub,"")}}
   }
   Label { text: redlineAppearance.text(("Installed games and pages matching: " + searchField.text), redlineAppearance.revision); color: redlineAppearance.color("#999", redlineAppearance.revision); wrapMode: Text.Wrap; Layout.fillWidth: true }
  }
  }
  }
 }
 StackLayout {
  anchors.fill: parent
  currentIndex: appWindow.section===6 && appWindow.subSection==="Hotkeys"?10:appWindow.section===2 && appWindow.subSection==="Graphics"?9:appWindow.section===0?0:appWindow.section===2 && appWindow.subSection==="Games"?1:appWindow.section===6 && ["System","Display","ReLive VR","Preferences"].indexOf(appWindow.subSection)>=0?2:appWindow.section===4 && appWindow.subSection==="Metrics"?3:appWindow.section===4 && appWindow.subSection==="Tuning"?5:appWindow.section===7?6:appWindow.section===1?7:appWindow.section===3 && (["Record","Media","Settings"].indexOf(appWindow.subSection)>=0)?8:4
  RedlineHome {
   onOpenAI:prompt=>{appWindow.navigateTo(1,"Chat","");aiPage.draft(prompt)}
   onOpenGames:appWindow.navigateTo(2,"Games","")
   onOpenCapture:appWindow.navigateTo(3,"Record","")
   onOpenGraphics:appWindow.navigateTo(2,"Graphics","")
   onShowDetails:(title,message)=>appWindow.showDetails(title,message)
   onOpenSettings:appWindow.navigate(6)
   onOpenProfiles:appWindow.openTuning()
   onOpenPerformance:appWindow.navigateTo(4,"Metrics","")
   onOpenGame:id=>appWindow.navigateTo(2,"Games",id)
  }
  RedlineLibrary {id:gameLibrary;onOpenGlobalDisplay:appWindow.navigateTo(6,"Display","");gameId:appWindow.selectedGame;store:uiStore;onOpenGame:id=>appWindow.navigateTo(2,"Games",id);onOpenHardware:appWindow.openTuning()}
  System {id:settingsPage;onOpenGames:appWindow.navigateTo(2,"Games","");store:uiStore;subpage:appWindow.subSection;onShowAbout:aboutDialog.open();onInformation:(title,message)=>appWindow.showDetails(title,message);onPreferenceSaved:message=>appWindow.showSaveToast(message)}
  RedlinePerformance {id:performancePage;onOpenGaming:appWindow.navigateTo(2,"Games","");store:uiStore;onOpenTuning:appWindow.openTuning()}
  RedlineFeaturePage {
   pageKey:appWindow.sectionNames[appWindow.section]+"/"+(appWindow.subSection==="Capture Settings" || appWindow.subSection==="Metrics Settings"?"Settings":appWindow.subSection)
   store:uiStore;onOpenHardware:appWindow.openTuning();onDetails:(title,message)=>appWindow.showDetails(title,message)
  }
  Profiles {id:profileUi}
  RedlineNotifications {objectName:"REDLINE_NOTIFICATIONS_PAGE";center:notificationCenter}
  RedlineAI {id:aiPage;subpage:appWindow.subSection;store:uiStore;onOpenChat:appWindow.navigateTo(1,"Chat","")}
  RedlineCapture {id:capturePage;subpage:appWindow.subSection;store:uiStore}
  RedlineGraphics {store:uiStore;onOpenGames:appWindow.navigateTo(2,"Games","")}
  RedlineHotkeys {store:uiStore;onOpenOverlay:{appWindow.navigateTo(4,"Metrics","");uiStore.write("perf.metrics.mode","Overlay")}}
 }

 RedlineShortcut {settingsStore:uiStore;action:"record";defaultSequence:"Ctrl+Shift+R";onActivated:{if(!captureBackend.active)appWindow.navigateTo(3,"Record","");capturePage.toggleRecording()}}
 RedlineShortcut {settingsStore:uiStore;action:"logging";defaultSequence:"Ctrl+Shift+L";onActivated:{if(nativeDashboard.logging)nativeDashboard.stopLogging();else nativeDashboard.startLogging()}}
 RedlineShortcut {settingsStore:uiStore;action:"games";defaultSequence:"Alt+G";onActivated:appWindow.navigateTo(2,"Games","")}
 RedlineShortcut {settingsStore:uiStore;action:"metrics";defaultSequence:"Alt+P";onActivated:appWindow.navigateTo(4,"Metrics","")}
 onClosing: close => { if (!systemTray.isAvailable() || !systemTray.isVisible()) Qt.quit() }
}
