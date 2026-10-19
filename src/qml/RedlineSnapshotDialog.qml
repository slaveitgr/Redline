// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Dialog {
 id:dialog
 parent:Overlay.overlay;anchors.centerIn:parent;modal:true;width:560
 property string mode:"actions"
 function tr(s){return redlineAppearance.text(s,redlineAppearance.revision)}
 function showReset(){mode="reset";open()}
 function showSnapshots(){mode="actions";open()}
 title:tr(mode==="reset"?"Reset application settings?":"Snap Settings")
 onClosed:settingsSnapshots.cancelImport()
 ColumnLayout {
  width:parent.width;spacing:16
  Label {text:dialog.tr("Snapshots include appearance, favorites, overlay and launch preferences. Hardware profiles and external Steam options are preserved.");wrapMode:Text.WordWrap;Layout.fillWidth:true;color:redlineAppearance.color("#ddd",redlineAppearance.revision)}
  RowLayout {
   visible:dialog.mode==="actions";Layout.fillWidth:true
   RedlineButton {text:"Import";Layout.fillWidth:true;onClicked:importFile.open()}
   RedlineButton {text:"Export";accent:true;Layout.fillWidth:true;onClicked:exportFile.open()}
  }
  Label {visible:dialog.mode==="import";text:settingsSnapshots.pendingCount+" · "+dialog.tr("validated settings will replace application preferences. Missing preferences return to defaults.");wrapMode:Text.WordWrap;Layout.fillWidth:true;color:redlineAppearance.color("#ddd",redlineAppearance.revision)}
  Label {visible:dialog.mode==="reset" || dialog.mode==="import";text:dialog.tr("A backup must be saved successfully before anything changes. Continue?");wrapMode:Text.WordWrap;Layout.fillWidth:true;color:redlineAppearance.color("#ddd",redlineAppearance.revision)}
  Label {text:dialog.tr(settingsSnapshots.message);visible:text.length>0;wrapMode:Text.WordWrap;Layout.fillWidth:true;color:redlineAppearance.color("#aaa",redlineAppearance.revision)}
  Label {text:dialog.tr("Backup")+": "+settingsSnapshots.backupPath;visible:settingsSnapshots.backupPath.length>0;wrapMode:Text.WrapAnywhere;Layout.fillWidth:true;color:redlineAppearance.color("#999",redlineAppearance.revision);font.pixelSize:11}
 }
 footer:Item {
  implicitHeight:64
  RowLayout {anchors.fill:parent;anchors.margins:12
  Item {Layout.fillWidth:true}
  RedlineButton {text:dialog.mode==="reset" || dialog.mode==="import"?"Cancel":"Close";onClicked:dialog.close()}
  RedlineButton {text:dialog.mode==="reset"?"Reset UI settings":"Import";accent:true;visible:dialog.mode==="reset" || dialog.mode==="import";onClicked:{var ok=dialog.mode==="reset"?settingsSnapshots.resetApplication():settingsSnapshots.applyImport();if(ok)dialog.mode="done"}}
  }
 }
 NativeFileDialog {id:exportFile;saveDlg:true;nameFilters:["Redline settings (*.json)"];onAccepted:settingsSnapshots.exportSnapshot(file)}
 NativeFileDialog {id:importFile;saveDlg:false;nameFilters:["Redline settings (*.json)"];onAccepted:{if(settingsSnapshots.prepareImport(file))dialog.mode="import"}}
}
