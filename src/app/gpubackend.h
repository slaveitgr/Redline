// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFileInfo>
#include <QCoreApplication>
#include <QQueue>
#include <QLocalSocket>
class GpuBackend final:public QObject {
 Q_OBJECT
 Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)
 Q_PROPERTY(QVariantMap stats READ stats NOTIFY changed)
 Q_PROPERTY(QVariantMap info READ info NOTIFY changed)
 Q_PROPERTY(QVariantMap clocks READ clocks NOTIFY changed)
 Q_PROPERTY(QVariantMap config READ config NOTIFY changed)
 Q_PROPERTY(QString deviceId READ deviceId NOTIFY changed)
 Q_PROPERTY(QString error READ error NOTIFY changed)
 Q_PROPERTY(bool ready READ ready NOTIFY changed)
 Q_PROPERTY(bool writable READ writable NOTIFY changed)
 Q_PROPERTY(int pendingSeconds READ pendingSeconds NOTIFY changed)
 public:
 explicit GpuBackend(QObject *parent=nullptr):QObject(parent){
  connect(&process_,&QProcess::readyReadStandardOutput,this,[this]{receive();});
  connect(&process_,&QProcess::errorOccurred,this,[this]{error_=process_.errorString();ready_=false;emit changed();});
  connect(&process_,&QProcess::finished,this,[this](int code){ready_=false;busy_=false;pending_=0;if(code)error_="GPU backend stopped: "+QString::fromUtf8(process_.readAllStandardError()).right(700);emit changed();});
  connect(&sample_,&QTimer::timeout,this,[this]{if(ready_ && !busy_ && queue_.isEmpty())enqueue("device_stats",{{"id",id_}});});sample_.start(1000);
  connect(&countdown_,&QTimer::timeout,this,[this]{if(pending_>0)--pending_;if(!pending_){countdown_.stop();enqueue("get_gpu_config",{{"id",id_}});}emit changed();});countdown_.setInterval(1000);
  QTimer::singleShot(0,this,[this]{start();});
 }
 ~GpuBackend(){if(socket_){socket_->disconnectFromServer();return;}process_.closeWriteChannel();if(!process_.waitForFinished(7500)){process_.terminate();process_.waitForFinished(1000);}}
 QVariantList devices()const{return devices_;} QVariantMap stats()const{return stats_;} QVariantMap info()const{return info_;} QVariantMap clocks()const{return clocks_;} QVariantMap config()const{return config_;}
 QString deviceId()const{return id_;} QString error()const{return error_;} bool ready()const{return ready_;} bool writable()const{return writable_ && ready_;} int pendingSeconds()const{return pending_;}
 Q_INVOKABLE void selectDevice(QString id){if(pending_ || busy_ || !queue_.isEmpty())return;for(auto v:devices_)if(v.toMap()["id"]==id){id_=id;refresh();break;}}
 Q_INVOKABLE void refresh(){if(id_.isEmpty())return;enqueue("device_info",{{"id",id_},{"include_api_info",true}});enqueue("device_stats",{{"id",id_}});enqueue("device_clocks_info",{{"id",id_}});enqueue("get_gpu_config",{{"id",id_}});}
 Q_INVOKABLE void apply(QVariantMap patch){
  if(!writable() || pending_ || patch.isEmpty())return;
  // Preserve fields not edited by this form.
  auto merged=config_;for(auto it=patch.begin();it!=patch.end();++it)merged[it.key()]=it.value();
  enqueue("set_gpu_config",{{"id",id_},{"config",QJsonObject::fromVariantMap(merged)}});
 }
 Q_INVOKABLE void confirm(bool keep){if(!pending_)return;enqueue("confirm_pending_config",{{"command",keep?"confirm":"revert"}});}
 private:
 struct Request{QString command;QJsonObject args;}; QQueue<Request> queue_;Request active_; QLocalSocket *socket_=nullptr;QProcess process_;QTimer sample_,countdown_;QByteArray buffer_;bool busy_=false,ready_=false,writable_=false;int pending_=0;QString error_,id_;QVariantList devices_;QVariantMap stats_,info_,clocks_,config_;
 void start(){
  const auto local=QCoreApplication::applicationDirPath()+"/../libexec/redline/redline-gpu-backend";
  writable_=!qEnvironmentVariableIsSet("REDLINE_READ_ONLY") && qEnvironmentVariableIsSet("REDLINE_GPU_ENGINE");
  if(writable_ && QFileInfo::exists("/run/redline-gpu.sock")){
   socket_=new QLocalSocket(this);
   connect(socket_,&QLocalSocket::connected,this,[this]{enqueue("list_devices",{});});
   connect(socket_,&QLocalSocket::readyRead,this,[this]{receive();});
   connect(socket_,&QLocalSocket::errorOccurred,this,[this]{error_="GPU service: "+socket_->errorString();ready_=false;emit changed();});
   socket_->connectToServer("/run/redline-gpu.sock");return;
  }
  if(writable_ && QFileInfo::exists("/usr/libexec/redline/redline-setup")){error_="Redline GPU service is unavailable. Run the one-time Redline setup.";emit changed();return;}
  if(writable_){if(!QFileInfo::exists("/usr/local/libexec/redline/redline-gpu-backend")){error_="Install the Redline GPU engine to enable GPU controls.";emit changed();return;}process_.start("/usr/bin/pkexec",{"/usr/local/libexec/redline/redline-gpu-backend"});}
  else process_.start(local,{"--read-only"});
  enqueue("list_devices",{});
 }
 void enqueue(QString command,QJsonObject args){queue_.enqueue({command,args});send();}
 void send(){if(busy_ || queue_.isEmpty() || (!socket_ && process_.state()==QProcess::NotRunning))return;active_=queue_.dequeue();busy_=true;QJsonObject payload{{"command",active_.command}};if(!active_.args.isEmpty())payload["args"]=active_.args;auto bytes=QJsonDocument(payload).toJson(QJsonDocument::Compact);if(socket_)socket_->write(bytes+'\n');else process_.write(bytes+'\n');}
 void receive(){buffer_+=socket_?socket_->readAll():process_.readAllStandardOutput();if(buffer_.size()>4*1024*1024){process_.terminate();return;}while(buffer_.contains('\n')){auto end=buffer_.indexOf('\n');auto line=buffer_.left(end);buffer_.remove(0,end+1);auto object=QJsonDocument::fromJson(line).object();busy_=false;
  if(object["status"]!="ok" && active_.command!="device_clocks_info"){error_=active_.command+": "+QString::fromUtf8(QJsonDocument(object["data"].toObject()).toJson(QJsonDocument::Compact));}
  else {
   if(active_.command!="device_stats")error_.clear();auto data=object["data"];
   if(active_.command=="list_devices"){devices_=data.toArray().toVariantList();ready_=true;qInfo("Redline integrated LACT GPU engine ready: %s",writable_?"authorized control":"diagnostic telemetry");if(!devices_.isEmpty()){id_=devices_[0].toMap()["id"].toString();refresh();}}
   else if(active_.command=="device_stats")stats_=data.toObject().toVariantMap();
   else if(active_.command=="device_info")info_=data.toObject().toVariantMap();
   else if(active_.command=="device_clocks_info")clocks_=data.toObject().toVariantMap();
   else if(active_.command=="get_gpu_config")config_=data.toObject().toVariantMap();
   else if(active_.command=="set_gpu_config"){pending_=data.toInt();countdown_.start();}
   else if(active_.command=="confirm_pending_config"){pending_=0;countdown_.stop();refresh();}
  }
  emit changed();send();
 }}
 signals:void changed();
};
