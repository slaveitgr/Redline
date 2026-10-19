// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "RedlineDesign.js" as Design
Item {
 id:page
 property var center
 function tr(value){return redlineAppearance.text(value,redlineAppearance.revision)}
 function shade(value){return redlineAppearance.color(value,redlineAppearance.revision)}
 ColumnLayout {
  anchors.fill:parent;anchors.margins:24;spacing:20
  RowLayout {
   Layout.fillWidth:true
   Label {text:page.tr("Notifications");font.pixelSize:22;color:page.shade("#eeeeee");Layout.fillWidth:true}
   RedlineButton {text:"Mark all as read";enabled:page.center.unreadCount>0;onClicked:page.center.markAllRead()}
   RedlineButton {text:"Remove read notifications";enabled:page.center.entries.count>page.center.unreadCount;onClicked:page.center.clearRead()}
  }
  Label {text:page.tr("Events from this Redline session");font.pixelSize:12;color:page.shade("#969696")}
  ListView {
   id:list;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:2;model:page.center.entries
   ScrollBar.vertical:ScrollBar {}
   delegate:Rectangle {
    id:notice
    required property int index
    required property string title
    required property string message
    required property string severity
    required property real createdAt
    required property bool isRead
    width:list.width;implicitHeight:noticeBody.implicitHeight+32;color:page.shade("#202020")
    RowLayout {
     id:noticeBody;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:16;spacing:14
     Rectangle {width:6;height:6;radius:3;color:Design.accent;visible:!notice.isRead;Layout.alignment:Qt.AlignTop;Layout.topMargin:10}
     ColumnLayout {
      Layout.fillWidth:true;spacing:8
      Label {text:page.tr(notice.title);font.pixelSize:16;font.bold:!notice.isRead;color:page.shade("#eeeeee");wrapMode:Text.WordWrap;Layout.fillWidth:true}
      Label {text:page.tr(notice.message);font.pixelSize:13;color:page.shade("#b0b0b0");wrapMode:Text.WordWrap;Layout.fillWidth:true}
      Label {text:Qt.formatDateTime(new Date(notice.createdAt),"dd/MM/yyyy HH:mm");font.pixelSize:11;color:page.shade("#808080")}
     }
     RedlineButton {text:"Mark as read";visible:!notice.isRead;onClicked:page.center.markRead(notice.index)}
     RedlineButton {text:"Remove";onClicked:page.center.remove(notice.index)}
    }
   }
   Label {anchors.centerIn:parent;visible:list.count===0;text:page.tr("No notifications.");font.pixelSize:16;color:page.shade("#969696")}
  }
 }
}
