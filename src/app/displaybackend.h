// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDBusConnection>
class DisplayBackend final : public QObject {
 Q_OBJECT
 Q_PROPERTY(QVariantList monitors READ monitors NOTIFY changed)
 Q_PROPERTY(bool supported READ supported NOTIFY changed)
 Q_PROPERTY(bool busy READ busy NOTIFY changed)
 Q_PROPERTY(QString message READ message NOTIFY changed)
public:
 explicit DisplayBackend(QObject *parent=nullptr):QObject(parent){
  connect(&process_,&QProcess::finished,this,[this](int code){
   const auto obj=QJsonDocument::fromJson(process_.readAllStandardOutput()).object();
   busy_=false;
   if(applying_){applying_=false;message_=code==0?"Confirm the change in the GNOME Keep Changes dialog. Unconfirmed changes revert automatically.":obj.value("error").toString("Display change failed.");emit changed();QTimer::singleShot(1500,this,&DisplayBackend::refresh);}
   else{supported_=code==0 && obj.value("supported").toBool() && obj.value("allowed").toBool();monitors_=obj.value("monitors").toArray().toVariantList();if(code)message_="Direct display controls require a supported GNOME session. Use desktop settings.";emit changed();}
  });
  connect(&process_,&QProcess::errorOccurred,this,[this](QProcess::ProcessError error){if(error==QProcess::FailedToStart){busy_=false;supported_=false;message_="Display helper could not start.";emit changed();}});
  connect(&process_,&QProcess::readyReadStandardError,this,[this]{process_.readAllStandardError();});
  QDBusConnection::sessionBus().connect("org.gnome.Mutter.DisplayConfig","/org/gnome/Mutter/DisplayConfig","org.gnome.Mutter.DisplayConfig","MonitorsChanged",this,SLOT(refresh()));
  refresh();
 }
 ~DisplayBackend(){disconnect(&process_,nullptr,this,nullptr);if(process_.state()!=QProcess::NotRunning){process_.kill();process_.waitForFinished(1000);}}
 QVariantList monitors()const{return monitors_;}bool supported()const{return supported_;}bool busy()const{return busy_;}QString message()const{return message_;}
 Q_INVOKABLE void apply(QString connector,QString mode,double scale,int color){
  if(busy_ || !supported_)return;
  if(qEnvironmentVariableIsSet("REDLINE_READ_ONLY")){message_="Display changes are disabled in UI preview.";emit changed();return;}
  applying_=true;run({"--apply",connector,mode,QString::number(scale,'g',12),QString::number(color)});
 }
public slots:
 void refresh(){if(!busy_)run({});}
private:
 QProcess process_;QVariantList monitors_;bool supported_=false,busy_=false,applying_=false;QString message_;
 void run(QStringList args){busy_=true;args.prepend(QCoreApplication::applicationDirPath()+"/../libexec/redline/redline-display.py");process_.start("/usr/bin/python3",args);emit changed();}
signals:void changed();
};
