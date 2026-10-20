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
#include <QJsonArray>
#include <QDir>
#include <QDateTime>
#include <QUuid>
#include <QDesktopServices>
#include <QUrl>
#include <algorithm>
class CaptureBackend final:public QObject {
 Q_OBJECT
 Q_PROPERTY(bool supported READ supported NOTIFY changed)
 Q_PROPERTY(bool audioSupported READ audioSupported NOTIFY changed)
 Q_PROPERTY(bool active READ active NOTIFY changed)
 Q_PROPERTY(bool replaySupported READ replaySupported NOTIFY changed)
 Q_PROPERTY(bool replayMode READ replayMode NOTIFY changed)
 Q_PROPERTY(QString state READ state NOTIFY changed)
 Q_PROPERTY(QString message READ message NOTIFY changed)
 Q_PROPERTY(int seconds READ seconds NOTIFY changed)
 Q_PROPERTY(QVariantList media READ media NOTIFY changed)
 Q_PROPERTY(QVariantList codecs READ codecs NOTIFY changed)
 Q_PROPERTY(bool screenshotBusy READ screenshotBusy NOTIFY changed)
 public:
 explicit CaptureBackend(QObject *parent=nullptr):QObject(parent){
  connect(&timer_,&QTimer::timeout,this,[this]{emit changed();});timer_.setInterval(1000);
  connect(&process_,&QProcess::readyReadStandardError,this,[this]{process_.readAllStandardError();});
  connect(&process_,&QProcess::readyReadStandardOutput,this,[this]{read();});
  connect(&process_,&QProcess::finished,this,[this](int code){read();timer_.stop();active_=false;if(code && state_!="error"){state_="error";message_="Recording failed. Check the desktop portal and media dependencies.";}else if(state_=="selecting" || state_=="stopping")state_="idle";refreshMedia();emit changed();});
  connect(&process_,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){if(e==QProcess::FailedToStart){active_=false;state_="error";message_="Could not start the capture service.";emit changed();}});
  auto check=new QProcess(this);connect(check,&QProcess::finished,this,[this,check](int){auto obj=QJsonDocument::fromJson(check->readAllStandardOutput().trimmed()).object();supported_=obj.value("supported").toBool();replaySupported_=obj.value("replay").toBool();audio_=obj.value("audio").toBool();codecs_=obj.value("codecs").toArray().toVariantList();if(!supported_)message_="Capture dependencies are unavailable.";check->deleteLater();emit changed();});
  check->start("/usr/bin/python3",{helper(),"--check"});refreshMedia();
 }
 ~CaptureBackend(){if(process_.state()!=QProcess::NotRunning){process_.write("stop\n");if(!process_.waitForFinished(3500)){process_.terminate();if(!process_.waitForFinished(3500)){process_.kill();process_.waitForFinished(500);}}}for(auto p:findChildren<QProcess*>()){disconnect(p,nullptr,this,nullptr);if(p->state()!=QProcess::NotRunning){p->terminate();if(!p->waitForFinished(2500)){p->kill();p->waitForFinished(500);}}}}
 bool replaySupported()const{return replaySupported_;}bool replayMode()const{return replayMode_;}
 bool supported()const{return supported_;}bool audioSupported()const{return audio_;}bool active()const{return active_;}QString state()const{return state_;}QString message()const{return message_;}int seconds()const{return active_ && elapsed_.isValid()?int(elapsed_.elapsed()/1000):finalSeconds_;}QVariantList media()const{return media_;}QVariantList codecs()const{return codecs_;}bool screenshotBusy()const{return screenshotBusy_;}
 Q_INVOKABLE void start(QVariantMap options){
  if(active_ || !supported_)return;
  if(qEnvironmentVariableIsSet("REDLINE_READ_ONLY")){message_="Screen recording is disabled in UI preview. Open normal Redline.";emit changed();return;}
  if(!QDir().mkpath(folder())){message_="Could not create the recordings folder.";emit changed();return;}
  replayMode_=options.value("replay",false).toBool();if(replayMode_ && !replaySupported_){message_="Replay requires ffmpeg and splitmuxsink.";emit changed();return;}
  const auto codec=replayMode_?QString("vp8"):options.value("codec","vp8").toString();QString extension;
  for(const auto &candidate:codecs_){const auto entry=candidate.toMap();if(entry.value("id").toString()==codec)extension=entry.value("extension").toString();}
  if(extension!="webm" && extension!="mp4"){message_="Selected encoder is unavailable. Choose an available encoder in recording settings.";emit changed();return;}
  const int fps=options.value("fps",30).toInt()==60?60:30;
  const int bitrate=qBound(2,options.value("bitrate",8).toInt(),100);
  auto resolution=options.value("resolution","native").toString();if(!QStringList{"native","720p","1080p"}.contains(resolution))resolution="native";
  output_=folder()+"/Redline-"+QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss")+"-"+QUuid::createUuid().toString(QUuid::WithoutBraces).left(8)+"."+extension;
  QStringList args{helper(),"--output",output_,"--fps",QString::number(fps),"--codec",codec,"--bitrate",QString::number(bitrate),"--resolution",resolution};
  if(replayMode_){int length=options.value("replaySeconds",30).toInt();if(!QList<int>{15,30,60,120}.contains(length))length=30;args<<"--replay-seconds"<<QString::number(length);}
  if(options.value("systemAudio",false).toBool() && audio_)args<<"--audio";
  if(options.value("microphone",false).toBool() && audio_)args<<"--microphone";
  buffer_.clear();elapsed_.invalidate();finalSeconds_=0;active_=true;state_="selecting";message_="Choose a screen or window in the system dialog.";emit changed();process_.start("/usr/bin/python3",args);
 }
 Q_INVOKABLE void takeScreenshot(){
  if(screenshotBusy_)return;
  if(qEnvironmentVariableIsSet("REDLINE_READ_ONLY")){message_="Screenshots are disabled in UI preview.";emit changed();return;}
  screenshotBusy_=true;message_="Choose a screenshot in the system dialog.";emit changed();auto process=new QProcess(this);
  connect(process,&QProcess::readyReadStandardError,process,[process]{process->readAllStandardError();});
  connect(process,&QProcess::finished,this,[this,process](int){auto obj=QJsonDocument::fromJson(process->readAllStandardOutput()).object();message_=obj.contains("saved")?"Screenshot saved.":obj.value("error").toString("Screenshot failed.");screenshotBusy_=false;refreshMedia();process->deleteLater();emit changed();});
  connect(process,&QProcess::errorOccurred,this,[this,process](QProcess::ProcessError e){if(e==QProcess::FailedToStart){message_="Could not start the screenshot portal helper.";screenshotBusy_=false;process->deleteLater();emit changed();}});
  process->start("/usr/bin/python3",{QCoreApplication::applicationDirPath()+"/../libexec/redline/redline-screenshot.py"});
 }
 Q_INVOKABLE void saveReplay(){if(active_ && replayMode_ && state_!="selecting" && state_!="stopping")process_.write("save-replay\n");}
 Q_INVOKABLE void stop(){if(active_){state_="stopping";process_.write("stop\n");emit changed();}}
 Q_INVOKABLE void refreshMedia(){media_.clear();QFileInfoList files;files+=QDir(folder()).entryInfoList({"*.webm","*.mp4"},QDir::Files|QDir::NoSymLinks);files+=QDir(pictures()).entryInfoList({"*.png"},QDir::Files|QDir::NoSymLinks);std::sort(files.begin(),files.end(),[](const auto &a,const auto &b){return a.lastModified()>b.lastModified();});for(const auto &info:files){if(info.size()>0 && !(active_ && info.absoluteFilePath()==output_))media_.append(QVariantMap{{"name",info.fileName()},{"path",info.absoluteFilePath()},{"size",QString::number(info.size()/1048576.,'f',1)+" MiB"},{"modified",info.lastModified().toString(Qt::ISODate)}});}emit changed();}
 Q_INVOKABLE void openFolder(){QDir().mkpath(folder());QDesktopServices::openUrl(QUrl::fromLocalFile(folder()));}
 Q_INVOKABLE bool openMedia(QString path){auto info=QFileInfo(path);const auto base=QFileInfo(info.suffix()=="png"?pictures():folder()).canonicalFilePath();return !base.isEmpty() && info.isFile() && !info.isSymLink() && QStringList{"webm","mp4","png"}.contains(info.suffix()) && info.canonicalPath()==base && QDesktopServices::openUrl(QUrl::fromLocalFile(info.canonicalFilePath()));}
 private:
 QProcess process_;QTimer timer_;QElapsedTimer elapsed_;QByteArray buffer_;bool supported_=false,audio_=false,active_=false,replaySupported_=false,replayMode_=false;int finalSeconds_=0;QString state_="idle",message_,output_;QVariantList media_,codecs_;bool screenshotBusy_=false;
 static QString helper(){return QCoreApplication::applicationDirPath()+"/../libexec/redline/redline-capture.py";}
 static QString pictures(){return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)+"/Redline";}
 static QString folder(){return QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)+"/Redline";}
 void read(){buffer_+=process_.readAllStandardOutput();if(buffer_.size()>65536)buffer_.remove(0,buffer_.size()-65536);while(buffer_.contains('\n')){int end=buffer_.indexOf('\n');auto obj=QJsonDocument::fromJson(buffer_.left(end)).object();buffer_.remove(0,end+1);auto next=obj.value("state").toString();if(next.isEmpty())continue;if(next.startsWith("replay-")){if(next=="replay-saved"){message_="Replay saved.";refreshMedia();}else if(next=="replay-exporting")message_="Saving replay…";else if(next=="replay-notice")message_=obj.value("message").toString();else if(next=="replay-ready")message_="Replay buffer active. Completed seconds: "+QString::number(obj.value("buffered").toInt());emit changed();continue;}state_=next;if(next=="saved" || next=="error")finalSeconds_=elapsed_.isValid()?int(elapsed_.elapsed()/1000):0;if(next=="recording"){elapsed_.start();timer_.start();message_=replayMode_?"Replay buffer active.":"Recording in progress.";}else if(next=="saved"){timer_.stop();message_="Recording saved.";}else if(next=="error"){message_=obj.value("message").toString().left(500);timer_.stop();}emit changed();}}
 signals:void changed();
};
