// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id:page
 property var store
 property string selectedLayer:"image"
 property var scenes:{var r=store.revision;return store.read("scene.list",[])}
 property int selectedIndex:{var r=store.revision;var id=store.read("scene.selected","");for(var i=0;i<scenes.length;i++)if(scenes[i].id===id)return i;return 0}
 property var scene:scenes.length?(scenes[selectedIndex] || {}):({})
 property bool enabledForCapture:{var r=store.revision;return store.read("scene.enabled",false)}
 property string overlay:sceneRenderer.preview(scene)
 function color(c){return redlineAppearance.color(c,redlineAppearance.revision)}
 function fresh(){return {id:"scene-"+Date.now()+"-"+Math.random().toString(36).slice(2,7),name:"Scene "+(scenes.length+1),imageEnabled:false,imagePath:"",imageX:.05,imageY:.05,imageWidth:.25,imageOpacity:1,textEnabled:false,text:"REDLINE",textX:.05,textY:.8,fontSize:40,textOpacity:1,textAbove:true}}
 function add(){if(scenes.length>=20)return;var list=JSON.parse(JSON.stringify(scenes));var next=fresh();list.push(next);store.write("scene.list",list);store.write("scene.selected",next.id)}
 function update(key,value){if(captureBackend.active || !scenes.length)return;var list=JSON.parse(JSON.stringify(scenes));list[selectedIndex][key]=value;store.write("scene.list",list)}
 function remove(){if(scenes.length<=1)return;var list=JSON.parse(JSON.stringify(scenes));list.splice(selectedIndex,1);store.write("scene.list",list);store.write("scene.selected",list[0].id)}
 Component.onCompleted:if(scenes.length===0)add()
 function verify(){var original=JSON.parse(JSON.stringify(scenes));var oldId=store.read("scene.selected","");var oldEnabled=store.read("scene.enabled",false);add();var valid=scenes.length===original.length+1;update("text","Scene test");store.write("scene.enabled",true);valid=valid && store.captureScene().text==="Scene test";remove();valid=valid && scenes.length===original.length;store.write("scene.list",original);store.write("scene.selected",oldId);store.write("scene.enabled",oldEnabled);return valid}
 ColumnLayout {
  anchors.fill:parent;anchors.margins:18;spacing:12
  RowLayout {Layout.fillWidth:true
   Label {text:"Scene Editor";font.pixelSize:22;color:page.color("#eee");Layout.fillWidth:true}
   CheckBox {text:"Use scene for capture";checked:page.enabledForCapture;enabled:!captureBackend.active && captureBackend.sceneSupported;onToggled:page.store.write("scene.enabled",checked)}
  }
  Label {text:"16:9 design canvas, scaled to the output. Select an image or text layer, then click the canvas to position it. Changes apply on the next capture; camera and live switching are not implemented.";wrapMode:Text.WordWrap;color:page.color("#999");Layout.fillWidth:true}
  RowLayout {
   Layout.fillWidth:true;Layout.fillHeight:true;spacing:14
   Rectangle {
    Layout.preferredWidth:320;Layout.fillHeight:true;color:page.color("#252528")
    ScrollView {
     anchors.fill:parent;anchors.margins:14;contentWidth:availableWidth;clip:true
     ColumnLayout {
      width:parent.width;spacing:12;enabled:!captureBackend.active
      ComboBox {model:page.scenes.map(function(s){return s.name});currentIndex:page.selectedIndex;Layout.fillWidth:true;onActivated:index=>page.store.write("scene.selected",page.scenes[index].id)}
      RowLayout {RedlineButton {text:"New scene";enabled:page.scenes.length<20;onClicked:page.add()}RedlineButton {text:"Delete";enabled:page.scenes.length>1;onClicked:page.remove()}}
      TextField {text:page.scene.name || "";placeholderText:"Scene name";maximumLength:60;Layout.fillWidth:true;onEditingFinished:page.update("name",text)}
      Label {text:"Sources";font.pixelSize:16;color:page.color("#ddd")}
      Label {text:"Screen / Window — chosen in the system dialog";wrapMode:Text.WordWrap;color:page.color("#999");Layout.fillWidth:true}
      RowLayout {RedlineButton {text:"Image";accent:page.selectedLayer==="image";onClicked:page.selectedLayer="image"}RedlineButton {text:"Text";accent:page.selectedLayer==="text";onClicked:page.selectedLayer="text"}}
      CheckBox {text:page.selectedLayer==="image"?"Show image":"Show text";checked:page.scene[page.selectedLayer+"Enabled"] || false;onToggled:page.update(page.selectedLayer+"Enabled",checked)}
      RedlineButton {visible:page.selectedLayer==="image";text:"Choose PNG / JPEG";onClicked:{var path=sceneRenderer.chooseImage();if(path.length){page.update("imagePath",path);page.update("imageEnabled",true)}}}
      Label {visible:page.selectedLayer==="image";text:page.scene.imagePath || "No image selected";elide:Text.ElideMiddle;color:page.color("#999");Layout.fillWidth:true}
      TextArea {visible:page.selectedLayer==="text";text:page.scene.text || "";placeholderText:"Overlay text";wrapMode:TextEdit.Wrap;Layout.fillWidth:true;Layout.preferredHeight:90;onActiveFocusChanged:if(!activeFocus)page.update("text",text.slice(0,200))}
      Label {text:"X position";color:page.color("#bbb")}
      Slider {from:0;to:1;value:page.scene[page.selectedLayer+"X"] || 0;Layout.fillWidth:true;onMoved:page.update(page.selectedLayer+"X",value)}
      Label {text:"Y position";color:page.color("#bbb")}
      Slider {from:0;to:1;value:page.scene[page.selectedLayer+"Y"] || 0;Layout.fillWidth:true;onMoved:page.update(page.selectedLayer+"Y",value)}
      Label {text:page.selectedLayer==="image"?"Image width":"Text size";color:page.color("#bbb")}
      Slider {from:page.selectedLayer==="image"?.02:12;to:page.selectedLayer==="image"?1:120;value:page.selectedLayer==="image"?(page.scene.imageWidth || .25):(page.scene.fontSize || 40);Layout.fillWidth:true;onMoved:page.update(page.selectedLayer==="image"?"imageWidth":"fontSize",value)}
      Label {text:"Opacity";color:page.color("#bbb")}
      Slider {from:0;to:1;value:page.scene[page.selectedLayer+"Opacity"]===undefined?1:page.scene[page.selectedLayer+"Opacity"];Layout.fillWidth:true;onMoved:page.update(page.selectedLayer+"Opacity",value)}
      CheckBox {text:"Text above image";checked:page.scene.textAbove!==false;onToggled:page.update("textAbove",checked)}
     }
    }
   }
   ColumnLayout {
    Layout.fillWidth:true;Layout.fillHeight:true
    Item {Layout.fillHeight:true}
    Rectangle {
     id:canvas;Layout.fillWidth:true;Layout.preferredHeight:width*9/16;color:"#101014";clip:true
     Label {anchors.centerIn:parent;text:"SCREEN / WINDOW\nSelected when capture starts";color:"#626269";horizontalAlignment:Text.AlignHCenter}
     Image {anchors.fill:parent;source:page.overlay;cache:false;fillMode:Image.Stretch}
     MouseArea {anchors.fill:parent;enabled:!captureBackend.active;onClicked:mouse=>{page.update(page.selectedLayer+"X",mouse.x/width);page.update(page.selectedLayer+"Y",mouse.y/height)}}
    }
    Label {text:sceneRenderer.issue(page.scene);visible:text.length>0;color:"#ed9d6a";wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Label {text:captureBackend.active?"Stop capture before editing the scene.":"Saved locally. Enable Use scene for capture to include these overlays in Record, Replay or Live Stream.";color:page.color("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Item {Layout.fillHeight:true}
   }
  }
 }
}
