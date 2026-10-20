// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <cmath>
#include <QImage>
#include <QImageReader>
#include <QPainter>
#include <QBuffer>
#include <QFileInfo>
#include <QFileDialog>
#include <QVariantMap>
#include <QUrl>
class SceneRenderer final:public QObject {
 Q_OBJECT
 public:using QObject::QObject;
 static double value(const QVariantMap &s,const char *key,double fallback,double low=0,double high=1){bool ok=false;double v=s.value(key,fallback).toDouble(&ok);return ok && std::isfinite(v)?qBound(low,v,high):fallback;}
 static QImage image(const QVariantMap &s,QString *error=nullptr){
  QImage canvas(1280,720,QImage::Format_ARGB32_Premultiplied);canvas.fill(Qt::transparent);QPainter painter(&canvas);
  auto picture=[&]{if(!s.value("imageEnabled",false).toBool())return;auto path=s.value("imagePath").toString();auto file=QFileInfo(path);QImageReader reader(path);auto format=reader.format().toLower();auto size=reader.size();
   if(!file.isAbsolute() || !file.isFile() || file.size()>20*1024*1024 || !QList<QByteArray>{"png","jpeg","jpg"}.contains(format) || !size.isValid() || qint64(size.width())*size.height()>16777216){if(error)*error="Choose a local PNG/JPEG image under 20 MiB and 16 megapixels.";return;}
   const auto width=qMax(1,int(1280*value(s,"imageWidth",.25,.02,1)));reader.setScaledSize(size.scaled(width,720,Qt::KeepAspectRatio));auto image=reader.read();if(image.isNull()){if(error)*error="Could not read the scene image.";return;}
   painter.save();painter.setOpacity(value(s,"imageOpacity",1));painter.drawImage(QPointF(1280*value(s,"imageX",.05),720*value(s,"imageY",.05)),image);painter.restore();};
  auto text=[&]{if(!s.value("textEnabled",false).toBool())return;painter.save();painter.setOpacity(value(s,"textOpacity",1));QFont font("Sans");font.setPixelSize(int(value(s,"fontSize",40,12,120)));painter.setFont(font);painter.setPen(Qt::white);const double x=1280*value(s,"textX",.05),y=720*value(s,"textY",.8);painter.drawText(QRectF(x,y,1280-x,720-y),Qt::AlignLeft|Qt::AlignTop|Qt::TextWordWrap,s.value("text").toString().left(200));painter.restore();};
  if(s.value("textAbove",true).toBool()){picture();text();}else{text();picture();}painter.end();return canvas;
 }
 Q_INVOKABLE QString preview(QVariantMap scene){auto canvas=image(scene);QByteArray bytes;QBuffer buffer(&bytes);buffer.open(QIODevice::WriteOnly);canvas.save(&buffer,"PNG");return "data:image/png;base64,"+QString::fromLatin1(bytes.toBase64());}
 Q_INVOKABLE QString issue(QVariantMap scene){QString error;image(scene,&error);return error;}
 Q_INVOKABLE QString chooseImage(){return QFileDialog::getOpenFileName(nullptr,"Scene image",QString(),"Images (*.png *.jpg *.jpeg)");}
};
