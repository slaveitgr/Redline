// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id: row
 property string title: redlineAppearance.text((""), redlineAppearance.revision)
 property string metricKey: ""
 property real scaleMaximum: 100
 property color traceColor: "#ed003b"
 color: redlineAppearance.color("#252527", redlineAppearance.revision); implicitHeight: 88
 RowLayout {
  anchors.fill: parent; spacing: 5
  Column {
   Layout.preferredWidth: Math.min(145,row.width*.48); Layout.fillHeight: true; padding: 12; spacing: 10
   Label { text: redlineAppearance.text((row.title), redlineAppearance.revision); color: redlineAppearance.color("#999", redlineAppearance.revision); font.pixelSize: 11 }
   Label { text: redlineAppearance.text((nativeDashboard.metrics[row.metricKey] || "N/A"), redlineAppearance.revision); color: redlineAppearance.color("#eee", redlineAppearance.revision); font.pixelSize: row.metricKey==="memory"?16:25 }
  }
  Canvas {
   id: chart; Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 10
   Connections {target:redlineAppearance;function onChanged(){chart.requestPaint()}}
   Connections { target: nativeDashboard; function onUpdated() { chart.requestPaint() } }
   onPaint: {
    var ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = redlineAppearance.color("#202022", redlineAppearance.revision); ctx.fillRect(0,0,width,height)
    ctx.strokeStyle = redlineAppearance.color("#2a2a2c", redlineAppearance.revision);ctx.lineWidth=1
    for(var g=0;g<5;g++){ctx.beginPath();ctx.moveTo(0,g*height/4);ctx.lineTo(width,g*height/4);ctx.stroke()}
    ctx.strokeStyle=row.traceColor;ctx.lineWidth=2;ctx.beginPath();var connected=false
    var data=nativeDashboard.history
    var newest=data.length?Number(data[data.length-1]._elapsedMs):0
    var duration=nativeDashboard.historyDurationSeconds*1000
    for(var i=0;i<data.length;i++){
     var raw=data[i][row.metricKey];var v=parseFloat(raw)
     if(isNaN(v)){connected=false;continue}
     var x=Math.max(0,Math.min(1,(Number(data[i]._elapsedMs)-newest+duration)/duration))*width;var y=height-(Math.max(0,Math.min(row.scaleMaximum,v))/row.scaleMaximum)*(height-5)
     if(connected)ctx.lineTo(x,y);else ctx.moveTo(x,y);connected=true
    }
    ctx.stroke()
   }
  }
 }
}
