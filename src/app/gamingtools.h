// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QRegularExpression>
#include <QVariantMap>
#include <QProcess>
#include <QStandardPaths>
#include <QFileInfo>
#include <QGuiApplication>
#include <QClipboard>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>
#include <QSaveFile>
#include <QDir>
#include <QFile>
class GamingTools final:public QObject {
 Q_OBJECT
 Q_PROPERTY(QString overlayConfigPath READ overlayConfigPath CONSTANT)
 Q_PROPERTY(QString message READ message NOTIFY changed)
 Q_PROPERTY(QString gameModeStatus READ gameModeStatus NOTIFY changed)
 public:
 explicit GamingTools(QObject *parent=nullptr):QObject(parent){
  connect(&timer_,&QTimer::timeout,this,[this]{status();});timer_.start(5000);status();
 }
 ~GamingTools(){
  timer_.stop();
  for(auto process:findChildren<QProcess*>(QString(),Qt::FindDirectChildrenOnly)){
   disconnect(process,nullptr,this,nullptr);
   if(process->state()!=QProcess::NotRunning){process->terminate();if(!process->waitForFinished(1000)){process->kill();process->waitForFinished(500);}}
  }
 }
 QString overlayConfigPath()const{
  if(qEnvironmentVariableIsSet("REDLINE_READ_ONLY"))return QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)+"/preview/MangoHud.conf";
  const auto snap=QDir::homePath()+"/snap/steam/common";
  return QFileInfo::exists(snap)?snap+"/redline/MangoHud.conf":QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)+"/MangoHud.conf";
 }
 static QByteArray overlayConfiguration(const QVariantMap &opts){
  QString position=opts.value("position","top-right").toString();if(!QStringList{"top-left","top-right","bottom-left","bottom-right"}.contains(position))position="top-right";
  const QStringList allowed{"fps","frametime","cpu_stats","gpu_stats","cpu_temp","gpu_temp","ram","vram","gpu_power","gpu_core_clock","gpu_fan","frame_timing"};
  const auto metrics=opts.value("metrics").toMap();QByteArray data;
  // Set every supported flag explicitly: omitted keys otherwise inherit MangoHud defaults.
  for(int i=0;i<allowed.size();++i)data+=(allowed[i]+"="+(metrics.value(allowed[i],i<8).toBool()?"1":"0")+"\n").toUtf8();
  QString hotkey=opts.value("hotkey","Shift_R+F12").toString();if(!QStringList{"Shift_R+F12","Shift_R+F11","Control_R+F12"}.contains(hotkey))hotkey="Shift_R+F12";
  data+=QString("position=%1\nfont_size=%2\nbackground_alpha=%3\nfps_limit=%4\nhorizontal=%5\ntoggle_hud=%6\n").arg(position).arg(qBound(12,opts.value("fontSize",20).toInt(),40)).arg(qBound(0,opts.value("opacity",50).toInt(),100)/100.,0,'f',2).arg(qBound(0,opts.value("fpsLimit",0).toInt(),240)).arg(opts.value("horizontal",false).toBool()?1:0).arg(hotkey).toUtf8();
  if(!opts.value("enabled",true).toBool())data+="no_display\n";
  return data;
 }
 Q_INVOKABLE void writeOverlay(QVariantMap opts){
  const auto data=overlayConfiguration(opts);
  QDir().mkpath(QFileInfo(overlayConfigPath()).absolutePath());QFile previous(overlayConfigPath());if(previous.open(QIODevice::ReadOnly)&&previous.readAll()==data)return;
  QSaveFile file(overlayConfigPath());if(!file.open(QIODevice::WriteOnly) || file.write(data)!=data.size() || !file.commit()){message_="Could not save overlay configuration.";emit changed();}
 }

 QString message()const{return message_;}QString gameModeStatus()const{return gameModeStatus_;}
 Q_INVOKABLE QVariantMap available(QString runtime="native")const{
  bool snap=runtime=="snap",flatpak=runtime=="flatpak";
  auto exists=[](QString name){return !QStandardPaths::findExecutable(name).isEmpty();};
  return {{"gamemode",!flatpak && (snap?QFileInfo::exists("/snap/steam/current/usr/bin/gamemoderun"):exists("gamemoderun"))},
   {"overlay",!flatpak && (snap?QFileInfo::exists("/snap/steam/current/usr/bin/mangohud"):exists("mangohud"))},
   {"gamescope",!flatpak && (snap?QFileInfo::exists("/snap/steam/current/usr/bin/gamescope"):exists("gamescope"))},
   {"mangoapp",!flatpak && (snap?QFileInfo::exists("/snap/steam/current/usr/bin/mangoapp"):exists("mangoapp"))}};
 }
 Q_INVOKABLE QString recipe(QVariantMap opts,QString runtime="native")const{
  auto tools=available(runtime);bool gm=opts.value("gamemode").toBool(),gs=opts.value("gamescope").toBool(),hud=opts.value("overlay").toBool();
  if((gm&&!tools["gamemode"].toBool())||(gs&&!tools["gamescope"].toBool())||(hud&&!tools["overlay"].toBool())||(gs&&hud&&!tools["mangoapp"].toBool()))return {};
  QStringList parts{"env","REDLINE_LAUNCH=1"};
  if(hud){QString path=overlayConfigPath();path.replace("'","'\\''");parts<<"MANGOHUD_CONFIGFILE='"+path+"'";}

  if(gm)parts<<"gamemoderun";
  if(gs){parts<<"gamescope"<<"-f";
   const QStringList resolutions{"1280x720","1600x900","1920x1080","2560x1440","3840x2160"};
   for(auto pair:QList<QPair<QString,QString>>{{"renderSize","-w"},{"outputSize","-W"}}){auto size=opts.value(pair.first).toString();if(resolutions.contains(size)){auto dimensions=size.split('x');parts<<pair.second<<dimensions[0]<<(pair.second=="-w"?"-h":"-H")<<dimensions[1];}}
   auto scaler=opts.value("scaler","auto").toString();if(QStringList{"integer","fit","fill","stretch"}.contains(scaler))parts<<"-S"<<scaler;
   auto filter=opts.value("filter","linear").toString();if(QStringList{"nearest","fsr","nis"}.contains(filter))parts<<"-F"<<filter;
if(hud)parts<<"--mangoapp";int fps=qBound(0,opts.value("fpsLimit",0).toInt(),240);if(fps>0)parts<<"-r"<<QString::number(fps);parts<<"--";}
  else if(hud)parts<<"mangohud";
  parts<<"%command%";return parts.join(' ');
 }
 Q_INVOKABLE void copy(QString text){if(!text.isEmpty()){QGuiApplication::clipboard()->setText(text);message_="Copied. Paste into the game's Steam launch options.";emit changed();}}
 Q_INVOKABLE void applyToSteam(QString root,QString id,QString options,bool restore=false){
  if(!QRegularExpression("^[0-9]+$").match(id).hasMatch())return;
  auto process=new QProcess(this);
  connect(process,&QProcess::finished,this,[this,process](int){auto response=QJsonDocument::fromJson(process->readAllStandardOutput()).object();message_=response.value("message").toString();if(message_.isEmpty())message_="Steam integration failed: "+QString::fromUtf8(process->readAllStandardError());emit changed();process->deleteLater();});
  QStringList args{QCoreApplication::applicationDirPath()+"/../libexec/redline/redline-steam-options.py","--steam-root",root,"--app-id",id};if(restore)args<<"--restore";else args<<"--options"<<options;
  process->start("/usr/bin/python3",args);
 }
 private:
 QTimer timer_;QString message_,gameModeStatus_="Unknown";bool statusPending_=false;
 void status(){if(statusPending_)return;auto exe=QStandardPaths::findExecutable("gamemoded");if(exe.isEmpty()){gameModeStatus_="Not installed";return;}statusPending_=true;auto p=new QProcess(this);connect(p,&QProcess::finished,this,[this,p](int){gameModeStatus_=QString::fromUtf8(p->readAllStandardOutput()).trimmed();statusPending_=false;emit changed();p->deleteLater();});p->start(exe,{"-s"});}
 signals:void changed();
};
