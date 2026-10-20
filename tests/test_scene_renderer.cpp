// SPDX-License-Identifier: GPL-3.0-or-later
#include "scenerenderer.h"
#include <QApplication>
#include <QTemporaryDir>
#include <cassert>
int main(int argc,char **argv){
 QApplication app(argc,argv);QTemporaryDir folder;QImage source(100,50,QImage::Format_ARGB32);source.fill(Qt::red);auto path=folder.path()+"/picture.png";assert(source.save(path));
 QString error;QVariantMap scene{{"imageEnabled",true},{"imagePath",path},{"imageWidth",.25},{"imageX",.1},{"imageY",.1},{"imageOpacity",.5}};
 auto rendered=SceneRenderer::image(scene,&error);assert(error.isEmpty());assert(rendered.size()==QSize(1280,720));auto pixel=rendered.pixelColor(130,74);assert(pixel.red()>240 && pixel.alpha()>120 && pixel.alpha()<136);assert(rendered.pixelColor(800,400).alpha()==0);
 scene["imagePath"]="/not/a/scene/image.svg";SceneRenderer::image(scene,&error);assert(!error.isEmpty());
 scene={{"textEnabled",true},{"text",QString::fromUtf8("Redline Ελλάδα")},{"textX",.1},{"textY",.1},{"fontSize",48}};rendered=SceneRenderer::image(scene);int visible=0;for(int y=60;y<200;y++)for(int x=100;x<700;x++)if(rendered.pixelColor(x,y).alpha())++visible;assert(visible>100);
 return 0;
}
