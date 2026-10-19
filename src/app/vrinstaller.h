// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QProcess>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>
#include <memory>
class VrInstaller final:public QObject {
 Q_OBJECT
 Q_PROPERTY(bool busy READ busy NOTIFY changed)
 Q_PROPERTY(int progress READ progress NOTIFY changed)
 Q_PROPERTY(QString message READ message NOTIFY changed)
 public:
 explicit VrInstaller(QObject *parent=nullptr):QObject(parent){}
 ~VrInstaller(){for(auto p:findChildren<QProcess*>()){disconnect(p,nullptr,this,nullptr);if(p->state()!=QProcess::NotRunning){p->kill();p->waitForFinished(500);}}}
 bool busy()const{return busy_;}int progress()const{return progress_;}QString message()const{return message_;}
 Q_INVOKABLE void install(QString backend){
  if(busy_)return;
  if(qEnvironmentVariableIsSet("REDLINE_READ_ONLY")){message_="Installation is disabled in UI preview. Open normal Redline.";emit changed();return;}
  if(backend!="ALVR" && backend!="WiVRn"){message_="Unknown VR backend.";emit changed();return;}
  busy_=true;progress_=-1;message_="Preparing installation…";emit changed();
  if(backend=="WiVRn"){flatpak_=QStandardPaths::findExecutable("flatpak");if(flatpak_.isEmpty()){finish(false,"Flatpak is missing. Open Flatpak setup first.");return;}findRemote(true);}
  else {
   auto helper=QCoreApplication::applicationDirPath()+"/../libexec/redline/redline-vr-install.py";
   run("/usr/bin/python3",{helper,"--destination",QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)+"/vr"},true);
  }
 }
 private:
 bool busy_=false;int progress_=-1;QString message_,flatpak_;
 void finish(bool ok,QString message){busy_=false;if(ok)progress_=100;message_=message;emit changed();if(ok)emit installed();}
 void findRemote(bool user){
  auto p=new QProcess(this);connect(p,&QProcess::errorOccurred,this,[this,p](QProcess::ProcessError e){if(e==QProcess::FailedToStart){p->deleteLater();finish(false,"Could not start Flatpak.");}});
  connect(p,&QProcess::finished,this,[this,p,user](int code){bool found=false;for(auto line:QString::fromUtf8(p->readAllStandardOutput()).split('\n')){auto columns=line.split('\t');if(columns.size()==2 && columns[0]=="flathub" && QStringList{"https://dl.flathub.org/repo/","https://dl.flathub.org/repo"}.contains(columns[1].trimmed()))found=true;}p->deleteLater();if(code==0 && found)run(flatpak_,{"install",user?"--user":"--system","--noninteractive","--assumeyes","flathub","io.github.wivrn.wivrn"},false);else if(user)findRemote(false);else finish(false,"Flathub is not configured. Open Flatpak setup first.");});
  QTimer::singleShot(5000,p,[p]{if(p->state()!=QProcess::NotRunning)p->kill();});p->start(flatpak_,{"remotes",user?"--user":"--system","--columns=name,url"});
 }
 void run(QString program,QStringList args,bool json){
  auto p=new QProcess(this);p->setProcessChannelMode(QProcess::MergedChannels);auto buffer=std::make_shared<QByteArray>();auto detail=std::make_shared<QString>();
  connect(p,&QProcess::readyReadStandardOutput,this,[this,p,buffer,detail,json]{*buffer+=p->readAllStandardOutput();if(buffer->size()>65536)buffer->remove(0,buffer->size()-65536);while(buffer->contains('\n')){auto end=buffer->indexOf('\n');auto line=buffer->left(end);buffer->remove(0,end+1);if(json){auto obj=QJsonDocument::fromJson(line).object();if(obj.contains("message")){message_=obj["message"].toString().left(500);*detail=message_;progress_=obj["progress"].toInt(-1);emit changed();}}}});
  connect(p,&QProcess::errorOccurred,this,[this,p](QProcess::ProcessError e){if(e==QProcess::FailedToStart){p->deleteLater();finish(false,"Could not start the VR installer.");}});
  connect(p,&QProcess::finished,this,[this,p,detail,json](int code){p->deleteLater();finish(code==0,code==0?"VR software installed. Open its setup wizard to continue.":json && !detail->isEmpty()?*detail:"Installation failed or was cancelled. Open the official setup guide for help.");});
  message_="Installing VR software…";emit changed();p->start(program,args);
 }
 signals:void changed();void installed();
};
