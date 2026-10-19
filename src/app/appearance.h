// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "settings.h"
#include <QApplication>
#include <QColor>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QTranslator>
#include <algorithm>
class RedlineTranslator final : public QTranslator {
 public:
 QMap<QString,QString> words;
 bool isEmpty() const override {return words.isEmpty();}
 QString translate(const char *,const char *source,const char *,int) const override {
  return words.value(QString::fromUtf8(source));
 }
};
class Appearance final : public QObject {
 Q_OBJECT
 Q_PROPERTY(bool light READ light NOTIFY changed)
 Q_PROPERTY(int revision READ revision NOTIFY changed)
 public:
 Appearance(Settings *settings,QQmlApplicationEngine *engine):QObject(engine),settings_(settings),engine_(engine){
  QFile file(":/translations/redline_el.json");if(file.open(QIODevice::ReadOnly)){
   const auto object=QJsonDocument::fromJson(file.readAll()).object();
   for(auto it=object.begin();it!=object.end();++it){translator_.words.insert(it.key(),it.value().toString());reverse_.insert(it.value().toString(),it.key());}
  }
  keys_=translator_.words.keys();std::sort(keys_.begin(),keys_.end(),[](const auto &a,const auto &b){return a.size()>b.size();});
  update();
  connect(settings_,&Settings::settingChanged,this,[this](const QString &key,const QVariant &){if(key=="Ui/theme"||key=="Ui/language"){update();++revision_;emit changed();engine_->retranslate();}});
 }
 ~Appearance() override {qApp->removeTranslator(&translator_);}
 bool light()const{return settings_->getValue("Ui/theme",QString("Dark")).toString()=="Light";}
 int revision()const{return revision_;}
 Q_INVOKABLE QString color(QString input,int=0)const {
  QColor c(input);if(!light()||!c.isValid()||c.alpha()==0)return input;
  const auto max=std::max({c.red(),c.green(),c.blue()}),min=std::min({c.red(),c.green(),c.blue()});
  if(max-min<=30){c.setRgb(255-c.red(),255-c.green(),255-c.blue(),c.alpha());return c.name(QColor::HexArgb);}
  return input;
 }
 Q_INVOKABLE QString text(QString input,int=0)const {
  if(!greek_){return reverse_.value(input,input);}
  if(translator_.words.contains(input))return translator_.words.value(input);
  if(input.startsWith("AMD ") || input.startsWith("Intel") || input.startsWith("NVIDIA") || input.startsWith("Linux Graphics Edition") || input.startsWith("Steam "))return input;
  // Translate composed captions while keeping route keys and stored values English.
  for(const auto &key:keys_)if(key.size()>3 && input.contains(key)){input.replace(key,translator_.words.value(key));}
  return input;
 }
 private:
 void update(){const auto language=settings_->getValue("Ui/language",QString("English")).toString();const bool next=language=="Ελληνικά"||language=="el";if(next!=greek_){greek_=next;if(greek_)qApp->installTranslator(&translator_);else qApp->removeTranslator(&translator_);}}
 Settings *settings_;QQmlApplicationEngine *engine_;RedlineTranslator translator_;QMap<QString,QString> reverse_;QStringList keys_;bool greek_=false;int revision_=0;
 signals:void changed();
};
