// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QProcess>
#include <QProcessEnvironment>
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
#include <QTemporaryDir>
#include "scenerenderer.h"
#include <QQuickImageProvider>
#include <QImage>
#include <QMutex>
#include <QMutexLocker>
#include <memory>
struct CapturePreviewFrame {QMutex mutex;QImage image;};
class CapturePreviewProvider final:public QQuickImageProvider {
 public:explicit CapturePreviewProvider(std::shared_ptr<CapturePreviewFrame> frame):QQuickImageProvider(QQuickImageProvider::Image),frame_(frame){}
 QImage requestImage(const QString &,QSize *size,const QSize &) override {QMutexLocker lock(&frame_->mutex);if(size)*size=frame_->image.size();return frame_->image;}
 private:std::shared_ptr<CapturePreviewFrame> frame_;
};
class CaptureBackend final:public QObject {
 Q_OBJECT
 Q_PROPERTY(bool cameraSupported READ cameraSupported NOTIFY changed)
 Q_PROPERTY(bool cameraPreview READ cameraPreview NOTIFY changed)
 Q_PROPERTY(bool sceneSupported READ sceneSupported NOTIFY changed)
 Q_PROPERTY(int previewFrame READ previewFrame NOTIFY previewChanged)
 Q_PROPERTY(bool previewAvailable READ previewAvailable NOTIFY previewChanged)
 Q_PROPERTY(double systemLevel READ systemLevel NOTIFY levelsChanged)
 Q_PROPERTY(double microphoneLevel READ microphoneLevel NOTIFY levelsChanged)
 Q_PROPERTY(bool streamingSupported READ streamingSupported NOTIFY changed)
 Q_PROPERTY(bool streaming READ streaming NOTIFY changed)
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
 explicit CaptureBackend(QObject *parent=nullptr,std::shared_ptr<CapturePreviewFrame> frame=std::make_shared<CapturePreviewFrame>()):QObject(parent),preview_(frame){
  connect(&process_,&QProcess::started,this,[this]{if(!streamConfig_.isEmpty()){process_.write(streamConfig_);streamConfig_.fill(0);streamConfig_.clear();}});
  connect(&timer_,&QTimer::timeout,this,[this]{emit changed();});timer_.setInterval(1000);
  connect(&process_,&QProcess::readyReadStandardError,this,[this]{process_.readAllStandardError();});
  connect(&process_,&QProcess::readyReadStandardOutput,this,[this]{read();});
  connect(&process_,&QProcess::finished,this,[this](int code){read();timer_.stop();active_=false;clearPreview();sceneFiles_.reset();if(code && state_!="error"){state_="error";message_="Recording failed. Check the desktop portal and media dependencies.";}else if(state_=="selecting" || state_=="stopping")state_="idle";refreshMedia();emit changed();});
  connect(&process_,&QProcess::errorOccurred,this,[this](QProcess::ProcessError e){if(e==QProcess::FailedToStart){streamConfig_.fill(0);streamConfig_.clear();active_=false;state_="error";message_="Could not start the capture service.";emit changed();}});
  auto check=new QProcess(this);connect(check,&QProcess::finished,this,[this,check](int){auto obj=QJsonDocument::fromJson(check->readAllStandardOutput().trimmed()).object();supported_=obj.value("supported").toBool();previewSupported_=obj.value("preview").toBool();sceneSupported_=obj.value("scenes").toBool();cameraSupported_=obj.value("camera").toBool();streamSupported_=obj.value("streaming").toBool();replaySupported_=obj.value("replay").toBool();audio_=obj.value("audio").toBool();codecs_=obj.value("codecs").toArray().toVariantList();if(!supported_)message_="Capture dependencies are unavailable.";check->deleteLater();emit changed();});
  check->start("/usr/bin/python3",{helper(),"--check"});refreshMedia();
 }
 ~CaptureBackend(){if(process_.state()!=QProcess::NotRunning){process_.write("stop\n");if(!process_.waitForFinished(3500)){process_.terminate();if(!process_.waitForFinished(3500)){process_.kill();process_.waitForFinished(500);}}}for(auto p:findChildren<QProcess*>()){disconnect(p,nullptr,this,nullptr);if(p->state()!=QProcess::NotRunning){p->terminate();if(!p->waitForFinished(2500)){p->kill();p->waitForFinished(500);}}}}
 bool replaySupported()const{return replaySupported_;}bool replayMode()const{return replayMode_;}
 bool cameraSupported()const{return cameraSupported_;}bool cameraPreview()const{return active_ && cameraOnly_;}
 bool sceneSupported()const{return sceneSupported_;}
 int previewFrame()const{return frameNumber_;}bool previewAvailable()const{QMutexLocker lock(&preview_->mutex);return !preview_->image.isNull();}double systemLevel()const{return systemLevel_;}double microphoneLevel()const{return microphoneLevel_;}
 bool streamingSupported()const{return streamSupported_;}bool streaming()const{return streamMode_;}
 bool supported()const{return supported_;}bool audioSupported()const{return audio_;}bool active()const{return active_;}QString state()const{return state_;}QString message()const{return message_;}int seconds()const{return active_ && elapsed_.isValid()?int(elapsed_.elapsed()/1000):finalSeconds_;}QVariantList media()const{return media_;}QVariantList codecs()const{return codecs_;}bool screenshotBusy()const{return screenshotBusy_;}
 Q_INVOKABLE void start(QVariantMap options){
  if(active_ || !supported_)return;
  if(qEnvironmentVariableIsSet("REDLINE_READ_ONLY")){message_="Screen recording is disabled in UI preview. Open normal Redline.";emit changed();return;}
  if(!QDir().mkpath(folder())){message_="Could not create the recordings folder.";emit changed();return;}
  cameraOnly_=false;cameraActive_=false;sceneSerial_=0;
  streamMode_=options.value("stream",false).toBool();
  if(streamMode_ && !streamSupported_){message_="Streaming requires H.264, AAC and RTMP GStreamer plugins.";emit changed();return;}
  replayMode_=options.value("replay",false).toBool();if(replayMode_ && !replaySupported_){message_="Replay requires ffmpeg and splitmuxsink.";emit changed();return;}
  const auto codec=streamMode_?QString("h264"):replayMode_?QString("vp8"):options.value("codec","vp8").toString();QString extension;
  for(const auto &candidate:codecs_){const auto entry=candidate.toMap();if(entry.value("id").toString()==codec)extension=entry.value("extension").toString();}
  if(extension!="webm" && extension!="mp4"){message_="Selected encoder is unavailable. Choose an available encoder in recording settings.";emit changed();return;}
  const int fps=options.value("fps",30).toInt()==60?60:30;
  const int bitrate=qBound(2,options.value("bitrate",8).toInt(),100);
  auto resolution=options.value("resolution","native").toString();if(!QStringList{"native","720p","1080p"}.contains(resolution))resolution="native";
  output_=folder()+"/Redline-"+QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss")+"-"+QUuid::createUuid().toString(QUuid::WithoutBraces).left(8)+"."+extension;
  QStringList args{helper(),"--output",output_,"--fps",QString::number(fps),"--codec",codec,"--bitrate",QString::number(bitrate),"--resolution",resolution};
  const bool archive=streamMode_ && options.value("archive",false).toBool();
  streamConfig_.clear();auto env=QProcessEnvironment::systemEnvironment();
  if(streamMode_){
   QUrl url(options.value("server").toString());auto key=options.value("key").toString();
   if(!url.isValid() || !QStringList{"rtmp","rtmps"}.contains(url.scheme()) || url.host().isEmpty() || !url.userInfo().isEmpty() || url.hasQuery() || url.hasFragment() || url.path().remove('/').isEmpty() || key.isEmpty() || key.size()>1024){message_="Enter a valid RTMP/RTMPS server URL and stream key.";emit changed();return;}
   streamConfig_=QJsonDocument(QJsonObject{{"server",url.toString()},{"key",key},{"audioBitrate",options.value("audioBitrate",128).toInt()}}).toJson(QJsonDocument::Compact)+'\n';
   args<<"--stream";if(archive)args<<"--archive";env.insert("GST_DEBUG","0");env.remove("GST_DEBUG_FILE");env.remove("GST_DEBUG_DUMP_DOT_DIR");
  }
  process_.setProcessEnvironment(env);
  if(replayMode_){int length=options.value("replaySeconds",30).toInt();if(!QList<int>{15,30,60,120}.contains(length))length=30;args<<"--replay-seconds"<<QString::number(length);}
  sceneFiles_.reset();auto scene=options.value("scene").toMap();
  if(!scene.isEmpty() || sceneSupported_){
   if(!sceneSupported_){message_="Scene composition requires the gdkpixbufoverlay plugin.";emit changed();return;}
   sceneFiles_=std::make_unique<QTemporaryDir>("/tmp/redline-scene-XXXXXX");QString error;auto image=SceneRenderer::image(scene,&error);
   const auto path=sceneFiles_->path()+"/overlay.png";
   if(!error.isEmpty() || !sceneFiles_->isValid() || !image.save(path,"PNG")){sceneFiles_.reset();message_=error.isEmpty()?"Could not prepare scene overlays.":error;emit changed();return;}
   args<<"--overlay-file"<<path;
   const auto camera=SceneRenderer::cameraSettings(scene);
   if(camera.value("enabled").toBool()){
    if(!cameraSupported_){message_="V4L2 camera/compositor plugins are unavailable.";emit changed();return;}
    QFile file(sceneFiles_->path()+"/camera.json");if(!file.open(QIODevice::WriteOnly)){message_="Could not prepare camera settings.";emit changed();return;}file.write(QJsonDocument::fromVariant(camera).toJson(QJsonDocument::Compact));file.close();
    args<<"--camera-file"<<file.fileName();cameraActive_=true;cameraDevice_=camera.value("device").toString();cameraResolution_=camera.value("resolution").toString();
   }
  }
  if(previewSupported_)args<<"--preview";
  if(options.value("systemAudio",false).toBool() && audio_)args<<"--audio";
  if(options.value("microphone",false).toBool() && audio_)args<<"--microphone";
  if(streamMode_ && !archive)output_.clear();
  clearPreview();buffer_.clear();elapsed_.invalidate();finalSeconds_=0;active_=true;state_="selecting";message_="Choose a screen or window in the system dialog.";emit changed();process_.start("/usr/bin/python3",args);
 }
 Q_INVOKABLE void previewCamera(QString device,QString resolution){
  if(active_ || !cameraSupported_ || !previewSupported_ || qEnvironmentVariableIsSet("REDLINE_READ_ONLY")){message_="Camera preview is unavailable while capturing or in Preview mode.";emit changed();return;}
  if(!QRegularExpression("^/dev/video[0-9]+$").match(device).hasMatch() || !QStringList{"auto","640x480","1280x720"}.contains(resolution)){message_="Choose a camera device and supported resolution.";emit changed();return;}
  streamConfig_.clear();sceneFiles_.reset();cameraOnly_=true;streamMode_=replayMode_=false;output_.clear();clearPreview();buffer_.clear();elapsed_.invalidate();finalSeconds_=0;active_=true;state_="selecting";message_="Opening camera preview. No recording is saved.";emit changed();process_.setProcessEnvironment(QProcessEnvironment::systemEnvironment());process_.start("/usr/bin/python3",{helper(),"--camera-preview","--camera-device",device,"--camera-resolution",resolution});
 }
 Q_INVOKABLE void applyScene(QVariantMap scene){
  if(!active_ || cameraOnly_ || !sceneFiles_ || !QStringList{"recording","streaming"}.contains(state_)){message_="Start capture before applying a live scene.";emit changed();return;}
  auto camera=SceneRenderer::cameraSettings(scene);
  if(camera.value("enabled").toBool() && (!cameraActive_ || camera.value("device").toString()!=cameraDevice_ || camera.value("resolution").toString()!=cameraResolution_)){message_="Stop capture to enable or change the camera device/resolution.";emit changed();return;}
  QString error;auto image=SceneRenderer::image(scene,&error);const auto path=sceneFiles_->path()+"/overlay-"+QString::number(++sceneSerial_).rightJustified(8,'0')+".png";
  if(!error.isEmpty() || !image.save(path,"PNG")){message_=error.isEmpty()?"Could not prepare live scene.":error;emit changed();return;}
  auto command=QJsonObject::fromVariantMap(QVariantMap{{"command","scene"},{"overlay",path},{"serial",sceneSerial_},{"camera",camera}});process_.write(QJsonDocument(command).toJson(QJsonDocument::Compact)+'\n');message_="Applying scene…";emit changed();
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
 std::unique_ptr<QTemporaryDir> sceneFiles_;
 std::shared_ptr<CapturePreviewFrame> preview_;int frameNumber_=0;bool previewSupported_=false,sceneSupported_=false,cameraSupported_=false,cameraOnly_=false,cameraActive_=false;int sceneSerial_=0;QString cameraDevice_,cameraResolution_;double systemLevel_=0,microphoneLevel_=0;
 void clearPreview(){{QMutexLocker lock(&preview_->mutex);preview_->image=QImage();}systemLevel_=microphoneLevel_=0;emit previewChanged();emit levelsChanged();}
 QProcess process_;QTimer timer_;QElapsedTimer elapsed_;QByteArray buffer_;bool streamSupported_=false,streamMode_=false;QByteArray streamConfig_;bool supported_=false,audio_=false,active_=false,replaySupported_=false,replayMode_=false;int finalSeconds_=0;QString state_="idle",message_,output_;QVariantList media_,codecs_;bool screenshotBusy_=false;
 static QString helper(){return QCoreApplication::applicationDirPath()+"/../libexec/redline/redline-capture.py";}
 static QString pictures(){return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)+"/Redline";}
 static QString folder(){return QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)+"/Redline";}
 void read(){buffer_+=process_.readAllStandardOutput();if(buffer_.size()>1048576)buffer_.remove(0,buffer_.size()-1048576);while(buffer_.contains('\n')){int end=buffer_.indexOf('\n');auto obj=QJsonDocument::fromJson(buffer_.left(end)).object();buffer_.remove(0,end+1);auto next=obj.value("state").toString();if(next.isEmpty())continue;if(next=="scene-applied" || next=="scene-rejected"){message_=next=="scene-applied"?"Scene applied without restarting capture.":obj.value("message").toString();if(next=="scene-applied" && sceneFiles_){int ack=obj.value("serial").toInt();for(const auto &f:QDir(sceneFiles_->path()).entryInfoList({"overlay*.png"},QDir::Files)){auto name=f.baseName();bool ok=false;int number=name.mid(8).toInt(&ok);if(name=="overlay" || (ok && number<ack))QFile::remove(f.absoluteFilePath());}}emit changed();continue;}if(next=="preview"){const auto encoded=obj.value("jpeg").toString().toLatin1();if(encoded.size()<=270000){auto image=QImage::fromData(QByteArray::fromBase64(encoded),"JPEG");if(!image.isNull() && image.size()==QSize(640,360)){{QMutexLocker lock(&preview_->mutex);preview_->image=image;}++frameNumber_;emit previewChanged();}}continue;}if(next=="audio-level"){const double value=qBound(0.0,obj.value("value").toDouble(),1.0);if(obj.value("source").toString()=="system-level")systemLevel_=value;else if(obj.value("source").toString()=="microphone-level")microphoneLevel_=value;emit levelsChanged();continue;}if(next.startsWith("replay-")){if(next=="replay-saved"){message_="Replay saved.";refreshMedia();}else if(next=="replay-exporting")message_="Saving replay…";else if(next=="replay-notice")message_=obj.value("message").toString();else if(next=="replay-ready")message_="Replay buffer active. Completed seconds: "+QString::number(obj.value("buffered").toInt());emit changed();continue;}state_=next;if(next=="saved" || next=="error" || next=="stream-stopped")finalSeconds_=elapsed_.isValid()?int(elapsed_.elapsed()/1000):0;if(next=="recording" || next=="streaming" || next=="camera-preview"){elapsed_.start();timer_.start();message_=cameraOnly_?"Camera preview active. No recording is saved.":streamMode_?"Sending stream. Check your service dashboard before making it public.":replayMode_?"Replay buffer active.":"Recording in progress.";}else if(next=="camera-stopped"){timer_.stop();message_="Camera preview stopped.";}else if(next=="stream-stopped"){timer_.stop();message_=obj.value("archived").toBool()?"Stream stopped. Local archive saved in Media.":"Stream stopped.";}else if(next=="saved"){timer_.stop();message_="Recording saved.";}else if(next=="error"){message_=obj.value("message").toString().left(500);timer_.stop();}emit changed();}}
 signals:void changed();void previewChanged();void levelsChanged();
};
