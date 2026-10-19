// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QElapsedTimer>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QDateTime>
#include <QUuid>
#include <QDesktopServices>
#include <QUrl>
class CaptureBackend final:public QObject {
 Q_OBJECT
 Q_PROPERTY(bool supported READ supported NOTIFY changed)
 Q_PROPERTY(bool audioSupported READ audioSupported NOTIFY changed)
 Q_PROPERTY(bool active READ active NOTIFY changed)
 Q_PROPERTY(QString state READ state NOTIFY changed)
 Q_PROPERTY(QString message READ message NOTIFY changed)
 Q_PROPERTY(int seconds READ seconds NOTIFY changed)
 Q_PROPERTY(QVariantList media READ media NOTIFY changed)
 public:
 explicit CaptureBackend(QObject *parent=nullptr):QObject(parent){
  connect(&timer_,&QTimer::timeout,this,[this]{emit changed();});timer_.setInterval(1000);
  connect(&process_,&QProcess::readyReadStandardError,this,[this]{process_.readAllStandardError();});
  connect(&process_,&QProcess::readyReadStandardOutput,this,[this]{read();});
  connect(&process_,&QProcess::finished,this,[this](int code){read();timer_.stop();active_=false;if(code && state_!="error"){state_="error";message_="Recording failed. Check the desktop portal and media dependencies.";}else if(state_=="selecting" || state_=="stopping")state_="idle";refreshMedia();emit changed();});
  connect(&process_,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){if(e==QProcess::FailedToStart){active_=false;state_="error";message_="Could not start the capture service.";emit changed();}});
  auto check=new QProcess(this);connect(check,&QProcess::finished,this,[this,check](int){auto obj=QJsonDocument::fromJson(check->readAllStandardOutput().trimmed()).object();supported_=obj.value("supported").toBool();audio_=obj.value("audio").toBool();if(!supported_)message_="Capture dependencies are unavailable.";check->deleteLater();emit changed();});
  check->start("/usr/bin/python3",{helper(),"--check"});refreshMedia();
 }
 ~CaptureBackend(){if(process_.state()!=QProcess::NotRunning){process_.write("stop\n");if(!process_.waitForFinished(3500)){process_.terminate();if(!process_.waitForFinished(3500)){process_.kill();process_.waitForFinished(500);}}}for(auto p:findChildren<QProcess*>()){disconnect(p,nullptr,this,nullptr);if(p->state()!=QProcess::NotRunning){p->kill();p->waitForFinished(500);}}}
 bool supported()const{return supported_;}bool audioSupported()const{return audio_;}bool active()const{return active_;}QString state()const{return state_;}QString message()const{return message_;}int seconds()const{return active_ && elapsed_.isValid()?int(elapsed_.elapsed()/1000):finalSeconds_;}QVariantList media()const{return media_;}
 Q_INVOKABLE void start(bool audio,int fps){
  if(active_ || !supported_)return;
  if(qEnvironmentVariableIsSet("REDLINE_READ_ONLY")){message_="Screen recording is disabled in UI preview. Open normal Redline.";emit changed();return;}
  if(!QDir().mkpath(folder())){message_="Could not create the recordings folder.";emit changed();return;}
  output_=folder()+"/Redline-"+QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss")+"-"+QUuid::createUuid().toString(QUuid::WithoutBraces).left(8)+".webm";
  QStringList args{helper(),"--output",output_,"--fps",fps==60?"60":"30"};if(audio && audio_)args<<"--audio";
  buffer_.clear();elapsed_.invalidate();finalSeconds_=0;active_=true;state_="selecting";message_="Choose a screen or window in the system dialog.";emit changed();process_.start("/usr/bin/python3",args);
 }
 Q_INVOKABLE void stop(){if(active_){state_="stopping";process_.write("stop\n");emit changed();}}
 Q_INVOKABLE void refreshMedia(){media_.clear();for(const auto &info:QDir(folder()).entryInfoList({"*.webm"},QDir::Files|QDir::NoSymLinks,QDir::Time)){if(info.size()>0 && !(active_ && info.absoluteFilePath()==output_))media_.append(QVariantMap{{"name",info.fileName()},{"path",info.absoluteFilePath()},{"size",QString::number(info.size()/1048576.,'f',1)+" MiB"},{"modified",info.lastModified().toString(Qt::ISODate)}});}emit changed();}
 Q_INVOKABLE void openFolder(){QDir().mkpath(folder());QDesktopServices::openUrl(QUrl::fromLocalFile(folder()));}
 Q_INVOKABLE bool openMedia(QString path){auto info=QFileInfo(path);return info.isFile() && !info.isSymLink() && info.suffix()=="webm" && info.canonicalFilePath().startsWith(QFileInfo(folder()).canonicalFilePath()+"/") && QDesktopServices::openUrl(QUrl::fromLocalFile(info.canonicalFilePath()));}
 private:
 QProcess process_;QTimer timer_;QElapsedTimer elapsed_;QByteArray buffer_;bool supported_=false,audio_=false,active_=false;int finalSeconds_=0;QString state_="idle",message_,output_;QVariantList media_;
 static QString helper(){return QCoreApplication::applicationDirPath()+"/../libexec/redline/redline-capture.py";}
 static QString folder(){return QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)+"/Redline";}
 void read(){buffer_+=process_.readAllStandardOutput();if(buffer_.size()>65536)buffer_.remove(0,buffer_.size()-65536);while(buffer_.contains('\n')){int end=buffer_.indexOf('\n');auto obj=QJsonDocument::fromJson(buffer_.left(end)).object();buffer_.remove(0,end+1);auto next=obj.value("state").toString();if(next.isEmpty())continue;state_=next;if(next=="saved" || next=="error")finalSeconds_=elapsed_.isValid()?int(elapsed_.elapsed()/1000):0;if(next=="recording"){elapsed_.start();timer_.start();message_="Recording in progress.";}else if(next=="saved"){timer_.stop();message_="Recording saved.";}else if(next=="error"){message_=obj.value("message").toString().left(500);timer_.stop();}emit changed();}}
 signals:void changed();
};
