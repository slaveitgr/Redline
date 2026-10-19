// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "settings.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSaveFile>
#include <QFile>
#include <QDir>
#include <QUrl>
#include <QDateTime>
#include <QUuid>
#include <QStandardPaths>
#include <QRegularExpression>
class SettingsSnapshots final:public QObject {
 Q_OBJECT
 Q_PROPERTY(QString message READ message NOTIFY changed)
 Q_PROPERTY(QString backupPath READ backupPath NOTIFY changed)
 Q_PROPERTY(int pendingCount READ pendingCount NOTIFY changed)
 public:
 explicit SettingsSnapshots(Settings *settings,QObject *parent=nullptr):QObject(parent),settings_(settings){}
 QString message()const{return message_;}QString backupPath()const{return backup_;}int pendingCount()const{return pending_.size();}
 Q_INVOKABLE bool exportSnapshot(QUrl url){if(!url.isLocalFile())return fail("Choose a local snapshot file.");if(!write(url.toLocalFile(),document(current())))return fail("Could not write the settings snapshot.");message_="Settings snapshot exported.";emit changed();return true;}
 Q_INVOKABLE bool prepareImport(QUrl url){
  pending_={};if(!url.isLocalFile())return fail("Choose a local snapshot file.");QFile file(url.toLocalFile());if(!file.open(QIODevice::ReadOnly) || file.size()>1024*1024)return fail("Snapshot is unreadable or too large.");
  QJsonParseError error;auto doc=QJsonDocument::fromJson(file.readAll(),&error);auto root=doc.object();
  if(error.error!=QJsonParseError::NoError || root.value("format")!="redline-ui-snapshot" || root.value("version")!=1 || !root.value("settings").isObject())return fail("Unsupported or invalid settings snapshot.");
  auto values=root.value("settings").toObject();if(values.isEmpty() || values.size()>10000)return fail("Snapshot has no settings or too many entries.");
  for(auto it=values.begin();it!=values.end();++it)if(!valid(it.key(),it.value()))return fail("Snapshot contains unsupported settings or invalid values.");
  pending_=values;message_="Snapshot validated. Confirm to replace application settings.";emit changed();return true;
 }
 Q_INVOKABLE void cancelImport(){pending_={};emit changed();}
 Q_INVOKABLE bool applyImport(){
  if(pending_.isEmpty())return fail("No validated snapshot is ready.");if(!backup())return false;
  auto values=pending_;pending_={};resetScope();for(auto it=values.begin();it!=values.end();++it)settings_->setValue(it.key(),it.value().toVariant());
  settings_->sync();message_=settings_->status()==QSettings::NoError?"Settings imported. Previous settings were backed up.":"Settings could not be fully saved. A backup is available.";emit applied();emit changed();return settings_->status()==QSettings::NoError;
 }
 Q_INVOKABLE bool resetApplication(){
  if(!backup())return false;
  resetScope();
  settings_->sync();message_=settings_->status()==QSettings::NoError?"Application settings reset. Hardware profiles were preserved.":"Settings could not be fully saved. A backup is available.";emit applied();emit changed();return settings_->status()==QSettings::NoError;
 }
 private:
 Settings *settings_;QString message_,backup_;QJsonObject pending_;
 void resetScope(){
  for(const auto &key:settings_->allKeys())if(key.startsWith("UiV6/")){settings_->remove(key);emit settings_->settingChanged(key,QVariant());}
  const auto values=defaults();for(auto it=values.begin();it!=values.end();++it)settings_->setValue(it.key(),it.value().toVariant());
 }
 static QJsonObject defaults(){return {{"Ui/theme","Dark"},{"Ui/language","English"},{"Ui/animations",true},{"Ui/toastNotifications",true},{"sysTray",true},{"startOnSysTray",false},{"saveWindowGeometry",true}};}
 static bool valid(QString key,QJsonValue value){
  if(key.startsWith("UiV6/") && !key.contains("//") && !key.split('/').contains("..") && !key.split('/').contains(".") && QRegularExpression("^UiV6/[A-Za-z0-9_. /-]{1,180}$").match(key).hasMatch()){
   if(!value.isString() || value.toString().size()>65536)return false;QJsonParseError error;auto doc=QJsonDocument::fromJson(("["+value.toString()+"]").toUtf8(),&error);return error.error==QJsonParseError::NoError && doc.isArray() && doc.array().size()==1;
  }
  auto allowed=defaults();if(!allowed.contains(key))return false;
  if(key=="Ui/theme")return value=="Dark" || value=="Light";
  if(key=="Ui/language")return value=="English" || value==QString::fromUtf8("Ελληνικά");
  return value.isBool();
 }
 QJsonObject current()const{QJsonObject values=defaults();auto base=defaults();for(const auto &key:settings_->allKeys()){
  QJsonValue value;if(base.contains(key))value=QJsonValue::fromVariant(settings_->getValue(key,base.value(key).toVariant()));else value=QJsonValue::fromVariant(settings_->value(key));if(valid(key,value))values[key]=value;
 }return values;}
 static QJsonObject document(QJsonObject values){return {{"format","redline-ui-snapshot"},{"version",1},{"created",QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},{"settings",values}};}
 static bool write(QString path,QJsonObject object){QSaveFile file(path);auto bytes=QJsonDocument(object).toJson();if(bytes.size()>1024*1024 || object.value("settings").toObject().size()>10000)return false;return file.open(QIODevice::WriteOnly) && file.write(bytes)==bytes.size() && file.commit();}
 bool backup(){auto dir=QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)+"/snapshots/backups";if(!QDir().mkpath(dir))return fail("Could not create a settings backup. Nothing was changed.");auto path=dir+"/settings-"+QUuid::createUuid().toString(QUuid::WithoutBraces)+".json";if(!write(path,document(current())))return fail("Could not create a settings backup. Nothing was changed.");backup_=path;return true;}
 bool fail(QString text){message_=text;emit changed();return false;}
 signals:void changed();void applied();
};
