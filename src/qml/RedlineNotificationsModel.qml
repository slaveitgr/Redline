// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
QtObject {
 id:center
 property ListModel entries:ListModel {}
 property int revision:0
 readonly property int unreadCount:{var change=revision;var count=0;for(var i=0;i<entries.count;i++)if(!entries.get(i).isRead)count++;return count}
 function add(key,title,message,severity){
  for(var i=0;i<entries.count;i++)if(entries.get(i).eventKey===key)return false
  entries.insert(0,{eventKey:key,title:title,message:message,severity:severity || "information",createdAt:Date.now(),isRead:false})
  if(entries.count>100)entries.remove(entries.count-1)
  revision++;return true
 }
 function markRead(index){if(index>=0 && index<entries.count){entries.setProperty(index,"isRead",true);revision++}}
 function markAllRead(){for(var i=0;i<entries.count;i++)entries.setProperty(i,"isRead",true);revision++}
 function remove(index){if(index>=0 && index<entries.count){entries.remove(index);revision++}}
 function clearRead(){for(var i=entries.count-1;i>=0;i--)if(entries.get(i).isRead)entries.remove(i);revision++}
}
