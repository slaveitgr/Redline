// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
 id:page
 property var store
 property string selectedLayer:"image"
 property var cameras:sceneRenderer.cameras()
 property string cameraDevice:scene.cameraDevice || (cameras.length?cameras[0].device:"")
 property var scenes:{var r=store.revision;return store.read("scene.list",[])}
 property int selectedIndex:{var r=store.revision;var id=store.read("scene.selected","");for(var i=0;i<scenes.length;i++)if(scenes[i].id===id)return i;return 0}
 property var scene:scenes.length?(scenes[selectedIndex] || {}):({})
 property bool enabledForCapture:{var r=store.revision;return store.read("scene.enabled",false)}
 property string overlay:sceneRenderer.preview(scene)
 function color(c){return redlineAppearance.color(c,redlineAppearance.revision)}
 function fresh(){return {id:"scene-"+Date.now()+"-"+Math.random().toString(36).slice(2,7),name:"Scene "+(scenes.length+1),imageEnabled:false,imagePath:"",imageX:.05,imageY:.05,imageWidth:.25,imageOpacity:1,textEnabled:false,text:"REDLINE",textX:.05,textY:.8,fontSize:40,textOpacity:1,textAbove:true,cameraEnabled:false,cameraDevice:cameras.length?cameras[0].device:"",cameraResolution:"auto",cameraX:.68,cameraY:.62,cameraWidth:.28,cameraHeight:.32,cameraOpacity:1}}
 function add(){if(scenes.length>=20)return;var list=JSON.parse(JSON.stringify(scenes));var next=fresh();list.push(next);store.write("scene.list",list);store.write("scene.selected",next.id)}
 function update(key,value){if(captureBackend.active || !scenes.length)return;var list=JSON.parse(JSON.stringify(scenes));list[selectedIndex][key]=value;store.write("scene.list",list)}
 function remove(){if(scenes.length<=1)return;var list=JSON.parse(JSON.stringify(scenes));list.splice(selectedIndex,1);store.write("scene.list",list);store.write("scene.selected",list[0].id)}
 function upgrade(){if(!scenes.length){add();return}var list=JSON.parse(JSON.stringify(scenes));var defaults={cameraEnabled:false,cameraDevice:cameras.length?cameras[0].device:"",cameraResolution:"auto",cameraX:.68,cameraY:.62,cameraWidth:.28,cameraHeight:.32,cameraOpacity:1};var changed=false;for(var i=0;i<list.length;i++)for(var key in defaults)if(list[i][key]===undefined){list[i][key]=defaults[key];changed=true}if(changed)store.write("scene.list",list)}
 Component.onCompleted:upgrade()
 function verify(){var original=JSON.parse(JSON.stringify(scenes));var oldId=store.read("scene.selected","");var oldEnabled=store.read("scene.enabled",false);add();var valid=scenes.length===original.length+1;update("text","Scene test");store.write("scene.enabled",true);valid=valid && store.captureScene().text==="Scene test";remove();valid=valid && scenes.length===original.length;var legacy=JSON.parse(JSON.stringify(scenes));delete legacy[0].cameraX;store.write("scene.list",legacy);upgrade();valid=valid && scenes[0].cameraX===.68;store.write("scene.list",original);store.write("scene.selected",oldId);store.write("scene.enabled",oldEnabled);return valid}
 ColumnLayout {
  anchors.fill:parent;anchors.margins:18;spacing:12
  RowLayout {Layout.fillWidth:true
   Label {text:"Scene Editor";font.pixelSize:22;color:page.color("#eee");Layout.fillWidth:true}
   CheckBox {text:"Use scene at capture start";checked:page.enabledForCapture;enabled:!captureBackend.active && captureBackend.sceneSupported;onToggled:page.store.write("scene.enabled",checked)}
  }
  Label {text:"16:9 design canvas, scaled to the output. Select an image or text layer, then click the canvas to position it. Use Apply selected scene live during capture. Camera device/resolution changes require Stop and a new capture.";wrapMode:Text.WordWrap;color:page.color("#999");Layout.fillWidth:true}
  RowLayout {
   Layout.fillWidth:true;Layout.fillHeight:true;spacing:14
   Rectangle {
    Layout.preferredWidth:320;Layout.fillHeight:true;color:page.color("#252528")
    ScrollView {
     anchors.fill:parent;anchors.margins:14;contentWidth:availableWidth;clip:true
     ColumnLayout {
      width:parent.width;spacing:12;enabled:true
      ComboBox {model:page.scenes.map(function(s){return s.name});currentIndex:page.selectedIndex;enabled:!captureBackend.cameraPreview;Layout.fillWidth:true;onActivated:index=>page.store.write("scene.selected",page.scenes[index].id)}
      RedlineButton {text:"Apply selected scene live";accent:true;visible:captureBackend.active && !captureBackend.cameraPreview;enabled:captureBackend.state==="recording" || captureBackend.state==="streaming";Layout.fillWidth:true;onClicked:captureBackend.applyScene(page.scene)}
      RedlineButton {text:captureBackend.cameraPreview?"Stop camera preview":"Preview camera — no recording";visible:page.selectedLayer==="camera";enabled:captureBackend.cameraPreview || (!redlineReadOnly && !captureBackend.active && captureBackend.cameraSupported && page.cameraDevice.length>0);Layout.fillWidth:true;onClicked:{if(captureBackend.cameraPreview)captureBackend.stop();else captureBackend.previewCamera(page.cameraDevice,page.scene.cameraResolution || "auto")}}
      ColumnLayout {Layout.fillWidth:true;enabled:!captureBackend.active
      RowLayout {RedlineButton {text:"New scene";enabled:page.scenes.length<20;onClicked:page.add()}RedlineButton {text:"Delete";enabled:page.scenes.length>1;onClicked:page.remove()}}
      TextField {text:page.scene.name || "";placeholderText:"Scene name";maximumLength:60;Layout.fillWidth:true;onEditingFinished:page.update("name",text)}
      Label {text:"Sources";font.pixelSize:16;color:page.color("#ddd")}
      Label {text:"Screen / Window — chosen in the system dialog";wrapMode:Text.WordWrap;color:page.color("#999");Layout.fillWidth:true}
      RowLayout {RedlineButton {text:"Image";accent:page.selectedLayer==="image";onClicked:page.selectedLayer="image"}RedlineButton {text:"Text";accent:page.selectedLayer==="text";onClicked:page.selectedLayer="text"}RedlineButton {text:"Camera";accent:page.selectedLayer==="camera";onClicked:page.selectedLayer="camera"}}
      CheckBox {text:page.selectedLayer==="image"?"Show image":page.selectedLayer==="camera"?"Use camera in capture":"Show text";checked:page.scene[page.selectedLayer+"Enabled"] || false;onToggled:{if(page.selectedLayer==="camera" && checked)page.update("cameraDevice",page.cameraDevice);page.update(page.selectedLayer+"Enabled",checked)}}
      RedlineButton {visible:page.selectedLayer==="image";text:"Choose PNG / JPEG";onClicked:{var path=sceneRenderer.chooseImage();if(path.length){page.update("imagePath",path);page.update("imageEnabled",true)}}}
      Label {visible:page.selectedLayer==="image";text:page.scene.imagePath || "No image selected";elide:Text.ElideMiddle;color:page.color("#999");Layout.fillWidth:true}
      TextArea {visible:page.selectedLayer==="text";text:page.scene.text || "";placeholderText:"Overlay text";wrapMode:TextEdit.Wrap;Layout.fillWidth:true;Layout.preferredHeight:90;onActiveFocusChanged:if(!activeFocus)page.update("text",text.slice(0,200))}
      ComboBox {visible:page.selectedLayer==="camera";model:page.cameras.map(function(c){return c.label});Layout.fillWidth:true;currentIndex:{for(var i=0;i<page.cameras.length;i++)if(page.cameras[i].device===page.cameraDevice)return i;return -1}onActivated:index=>page.update("cameraDevice",page.cameras[index].device)}
      RedlineButton {text:"Refresh camera list";visible:page.selectedLayer==="camera";onClicked:page.cameras=sceneRenderer.cameras()}
      ComboBox {visible:page.selectedLayer==="camera";model:["auto","640x480","1280x720"];currentIndex:model.indexOf(page.scene.cameraResolution || "auto");Layout.fillWidth:true;onActivated:index=>page.update("cameraResolution",model[index])}
      Label {visible:page.selectedLayer==="camera";text:"Only Preview camera or starting capture with Use camera enabled opens the device.";color:page.color("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true}
      Label {text:"X position";color:page.color("#bbb")}
      Slider {from:0;to:1;value:page.scene[page.selectedLayer+"X"] || 0;Layout.fillWidth:true;onMoved:page.update(page.selectedLayer+"X",value)}
      Label {text:"Y position";color:page.color("#bbb")}
      Slider {from:0;to:1;value:page.scene[page.selectedLayer+"Y"] || 0;Layout.fillWidth:true;onMoved:page.update(page.selectedLayer+"Y",value)}
      Label {text:page.selectedLayer==="text"?"Text size":"Layer width";color:page.color("#bbb")}
      Slider {from:page.selectedLayer==="text"?12:.02;to:page.selectedLayer==="text"?120:1;value:page.selectedLayer==="text"?(page.scene.fontSize || 40):(page.scene[page.selectedLayer+"Width"] || .25);Layout.fillWidth:true;onMoved:page.update(page.selectedLayer==="text"?"fontSize":page.selectedLayer+"Width",value)}
      Label {text:"Camera height";visible:page.selectedLayer==="camera";color:page.color("#bbb")}
      Slider {visible:page.selectedLayer==="camera";from:.02;to:1;value:page.scene.cameraHeight || .32;Layout.fillWidth:true;onMoved:page.update("cameraHeight",value)}
      Label {text:"Opacity";color:page.color("#bbb")}
      Slider {from:0;to:1;value:page.scene[page.selectedLayer+"Opacity"]===undefined?1:page.scene[page.selectedLayer+"Opacity"];Layout.fillWidth:true;onMoved:page.update(page.selectedLayer+"Opacity",value)}
      CheckBox {text:"Text above image";checked:page.scene.textAbove!==false;onToggled:page.update("textAbove",checked)}
      }
     }
    }
   }
   ColumnLayout {
    Layout.fillWidth:true;Layout.fillHeight:true
    Item {Layout.fillHeight:true}
    Rectangle {
     id:canvas;Layout.fillWidth:true;Layout.preferredHeight:width*9/16;color:"#101014";clip:true
     Label {anchors.centerIn:parent;text:"SCREEN / WINDOW\nSelected when capture starts";color:"#626269";horizontalAlignment:Text.AlignHCenter}
     RedlineCapturePreview {anchors.fill:parent;visible:captureBackend.active && !captureBackend.cameraPreview && captureBackend.previewAvailable}
     Rectangle {visible:(page.scene.cameraEnabled || captureBackend.cameraPreview) && (!captureBackend.active || captureBackend.cameraPreview);x:canvas.width*Math.min(page.scene.cameraX===undefined?.68:page.scene.cameraX,1-(page.scene.cameraWidth || .28));y:canvas.height*Math.min(page.scene.cameraY===undefined?.62:page.scene.cameraY,1-(page.scene.cameraHeight || .32));width:canvas.width*(page.scene.cameraWidth || .28);height:canvas.height*(page.scene.cameraHeight || .32);color:"#202026";border.color:"#ed003b";opacity:page.scene.cameraOpacity===undefined?1:page.scene.cameraOpacity
      Label {anchors.centerIn:parent;text:"CAMERA";color:"#aaa"}
      RedlineCapturePreview {anchors.fill:parent;visible:captureBackend.cameraPreview && captureBackend.previewAvailable}
     }
     Image {visible:!captureBackend.active || captureBackend.cameraPreview;anchors.fill:parent;source:page.overlay;cache:false;fillMode:Image.Stretch}
     MouseArea {anchors.fill:parent;enabled:!captureBackend.active;onClicked:mouse=>{page.update(page.selectedLayer+"X",mouse.x/width);page.update(page.selectedLayer+"Y",mouse.y/height)}}
    }
    Label {text:captureBackend.message;visible:captureBackend.active || text.length>0;color:page.color("#bbb");wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Label {text:sceneRenderer.issue(page.scene);visible:text.length>0;color:"#ed9d6a";wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Label {text:captureBackend.active?"Select a saved scene and Apply selected scene live. A hidden camera remains open until capture stops.":"Saved locally. Enable Use scene at capture start to include these overlays in Record, Replay or Live Stream.";color:page.color("#999");wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Item {Layout.fillHeight:true}
   }
  }
 }
}
