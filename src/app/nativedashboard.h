// SPDX-License-Identifier: GPL-3.0-or-later
// Redline fork: local dashboard presentation model. No privileged operations.
#pragma once
#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QTimer>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QDesktopServices>
#include <QUrl>
#include <QSysInfo>
#include <QGuiApplication>
#include <QScreen>
#include <QFileInfo>
#include <QThread>
#include <QProcess>
#include <QDateTime>
#include <QElapsedTimer>
class NativeDashboard final : public QObject {
 Q_OBJECT
 Q_PROPERTY(int samplingIntervalMs READ samplingIntervalMs NOTIFY samplingSettingsChanged)
 Q_PROPERTY(int historyDurationSeconds READ historyDurationSeconds NOTIFY samplingSettingsChanged)
 Q_PROPERTY(bool logging READ logging NOTIFY loggingChanged)
 Q_PROPERTY(QString loggingPath READ loggingPath NOTIFY loggingChanged)
 Q_PROPERTY(QVariantMap metrics READ metrics NOTIFY updated)
 Q_PROPERTY(QVariantList games READ games CONSTANT)
 Q_PROPERTY(QVariantMap systemInfo READ systemInfo CONSTANT)
 Q_PROPERTY(QVariantList displays READ displays NOTIFY displaysChanged)
 Q_PROPERTY(QVariantList history READ history NOTIFY updated)
 public:
 explicit NativeDashboard(QObject *parent=nullptr):QObject(parent) {
  QDir drm("/sys/class/drm");
  for(const auto &card:drm.entryList({"card[0-9]*"},QDir::Dirs)) {
   auto d=drm.filePath(card+"/device");
   if(read(d+"/vendor")=="0x1002") {device_=d;break;}
  }
  if(!device_.isEmpty())for(const auto &h:QDir(device_+"/hwmon").entryList({"hwmon*"},QDir::Dirs)) {
   QString p=device_+"/hwmon/"+h;if(read(p+"/name")=="amdgpu"){hwmon_=p;break;}
  }
  scanSystemInfo();scanDisplays();
  connect(qGuiApp,&QGuiApplication::screenAdded,this,[this](QScreen*){scanDisplays();});
  connect(qGuiApp,&QGuiApplication::screenRemoved,this,[this](QScreen*){scanDisplays();});
  historyClock_.start();
  scanGames();connect(&timer_,&QTimer::timeout,this,&NativeDashboard::sample);timer_.start(1000);sample();
 }
 QVariantMap metrics()const{return metrics_;}
 QVariantList games()const{return games_;}
 QVariantMap systemInfo()const{return systemInfo_;}
 QVariantList displays()const{return displays_;}
 Q_INVOKABLE void refreshDisplays(){scanDisplays();}
 Q_INVOKABLE bool desktopSettingsAvailable() const {return !QStandardPaths::findExecutable("gnome-control-center").isEmpty();}
 Q_INVOKABLE bool openDesktopSettings(QString panel) {
  if(panel!="display" && panel!="color")return false;
  const auto executable=QStandardPaths::findExecutable("gnome-control-center");
  return !executable.isEmpty() && QProcess::startDetached(executable,QStringList{panel});
 }
 QVariantList history()const{return history_;}
 int samplingIntervalMs()const{return timer_.interval();}
 int historyDurationSeconds()const{return historyDurationSeconds_;}
 Q_INVOKABLE void configureSampling(int intervalMs,int durationSeconds){
  intervalMs=qBound(250,intervalMs,5000);durationSeconds=qBound(10,durationSeconds,120);
  if(intervalMs==timer_.interval() && durationSeconds==historyDurationSeconds_)return;
  timer_.setInterval(intervalMs);historyDurationSeconds_=durationSeconds;
  trimHistory();emit samplingSettingsChanged();emit updated();
 }
 bool logging()const{return logFile_.isOpen();}
 QString loggingPath()const{return logFile_.fileName();}
 Q_INVOKABLE bool startLogging(){
  if(logging())return true;
  auto folder=QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)+"/logs";
  if(!QDir().mkpath(folder))return false;
  logFile_.setFileName(folder+"/metrics-"+QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss-zzz")+".csv");
  if(!logFile_.open(QIODevice::WriteOnly|QIODevice::NewOnly))return false;
  logFile_.write("timestamp_utc,gpu_percent,gpu_temperature_c,gpu_power_w,gpu_clock_mhz,cpu_percent,cpu_temperature_c,ram_used_gib\n");
  logFile_.flush();emit loggingChanged();return true;
 }
 Q_INVOKABLE void stopLogging(){if(logging()){logFile_.close();emit loggingChanged();}}
 Q_INVOKABLE bool openLogs(){return QDesktopServices::openUrl(QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)+"/logs"));}

 Q_INVOKABLE bool openProjectPage(QString page){
  const QMap<QString,QString> pages{{"issues","https://github.com/slaveitgr/Redline/issues"},{"source","https://github.com/slaveitgr/Redline"}};
  return pages.contains(page) && QDesktopServices::openUrl(QUrl(pages.value(page)));
 }

 Q_INVOKABLE bool launchGame(QString id) {
  for(const auto &v:games_)if(v.toMap()["id"].toString()==id)return QDesktopServices::openUrl(QUrl("steam://rungameid/"+id));
  return false;
 }
 signals:void samplingSettingsChanged();void updated();void displaysChanged();void loggingChanged();
 private:
 QFile logFile_;
 QElapsedTimer historyClock_;
 int historyDurationSeconds_=60;
 void trimHistory(){
  const auto cutoff=historyClock_.elapsed()-qint64(historyDurationSeconds_)*1000;
  while(!history_.isEmpty() && history_.first().toMap().value("_elapsedMs").toLongLong()<cutoff)history_.removeFirst();
 }
 static QString read(QString path){QFile f(path);return f.open(QIODevice::ReadOnly)?QString::fromUtf8(f.readAll()).trimmed():QString();}
 static QString value(QString path,double scale,QString unit,int decimals=0){bool ok=false;double n=read(path).toDouble(&ok);return ok?QString::number(n/scale,'f',decimals)+unit:"N/A";}
 void scanSystemInfo(){
  systemInfo_["os"]=QSysInfo::prettyProductName();systemInfo_["kernel"]=QSysInfo::kernelVersion();
  systemInfo_["architecture"]=QSysInfo::currentCpuArchitecture();
  auto cpu=QRegularExpression("model name\\s*:\\s*([^\\n]+)").match(read("/proc/cpuinfo"));
  systemInfo_["cpuName"]=cpu.hasMatch()?cpu.captured(1):"Unavailable";
  systemInfo_["threads"]=QThread::idealThreadCount();
  auto memory=QRegularExpression("MemTotal:\\s+(\\d+)").match(read("/proc/meminfo"));
  systemInfo_["memoryTotal"]=memory.hasMatch()?QString::number(memory.captured(1).toDouble()/1048576.,'f',1)+" GiB":"Unavailable";
  systemInfo_["machine"]=read("/sys/class/dmi/id/product_name");
  systemInfo_["vendor"]=read(device_+"/vendor");systemInfo_["device"]=read(device_+"/device");
  systemInfo_["subsystemVendor"]=read(device_+"/subsystem_vendor");systemInfo_["subsystemDevice"]=read(device_+"/subsystem_device");
  systemInfo_["revision"]=read(device_+"/revision");systemInfo_["bios"]=read(device_+"/vbios_version");
  systemInfo_["driver"]=QFileInfo(QFileInfo(device_+"/driver").symLinkTarget()).fileName();
  systemInfo_["vram"]=value(device_+"/mem_info_vram_total",1048576," MiB");
 }
 void scanDisplays(){
  QVariantList found;
  for(auto screen:QGuiApplication::screens()){
   const auto size=screen->size();const auto mm=screen->physicalSize();
   found.append(QVariantMap{{"name",screen->name()},{"model",screen->model()},{"manufacturer",screen->manufacturer()},
    {"resolution",QString::number(size.width())+" × "+QString::number(size.height())},
    {"refreshRate",QString::number(screen->refreshRate(),'f',1)+" Hz"},
    {"scale",QString::number(screen->devicePixelRatio()*100.,'f',0)+"%"},
    {"physicalSize",QString::number(mm.width(),'f',0)+" × "+QString::number(mm.height(),'f',0)+" mm"},
    {"depth",QString::number(screen->depth())+" bits (Qt surface)"}});
  }
  if(found!=displays_){displays_=found;emit displaysChanged();}
 }
 void sample(){
  metrics_["cpuTemperature"]="N/A";
  for(const auto &hw:QDir("/sys/class/hwmon").entryList({"hwmon*"},QDir::Dirs)) {
   const auto base="/sys/class/hwmon/"+hw;
   if(read(base+"/name")=="k10temp"){metrics_["cpuTemperature"]=value(base+"/temp1_input",1000," °C",1);break;}
  }
  metrics_["gpu"]= value(device_+"/gpu_busy_percent",1,"%");
  metrics_["temperature"]=value(hwmon_+"/temp1_input",1000," °C");
  metrics_["power"]=value(hwmon_+"/power1_input",1000000," W",1);
  metrics_["fan"]=value(hwmon_+"/fan1_input",1," RPM");
  metrics_["memoryClock"]=value(hwmon_+"/freq2_input",1000000," MHz");
  metrics_["vramUsed"]=value(device_+"/mem_info_vram_used",1048576," MiB",0);
  metrics_["vramTotal"]=value(device_+"/mem_info_vram_total",1048576," MiB",0);
  metrics_["clock"]= value(hwmon_+"/freq1_input",1000000," MHz");
  auto mem=read("/proc/meminfo");QRegularExpression totalRe("MemTotal:\\s+(\\d+)"),availRe("MemAvailable:\\s+(\\d+)");
  auto t=totalRe.match(mem),a=availRe.match(mem);
  metrics_["memory"]=t.hasMatch()&&a.hasMatch()?QString::number((t.captured(1).toDouble()-a.captured(1).toDouble())/1048576.,'f',1)+" / "+QString::number(t.captured(1).toDouble()/1048576.,'f',1)+" GiB":"N/A";
  const auto cpuLine=read("/proc/stat").split('\n').value(0).simplified().split(' ');
  if(cpuLine.size()>=9){qulonglong total=0;for(int i=1;i<=8;i++)total+=cpuLine[i].toULongLong();auto idle=cpuLine[4].toULongLong()+cpuLine[5].toULongLong();
   metrics_["cpu"]=lastTotal_&&total>lastTotal_?QString::number(100.*(1.-double(idle-lastIdle_)/double(total-lastTotal_)),'f',0)+"%":"N/A";lastTotal_=total;lastIdle_=idle;
  }
  if(logging()){
   QStringList values{QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)};
   for(const auto &key:{"gpu","temperature","power","clock","cpu","cpuTemperature","memory"}){
    const auto match=QRegularExpression("^[0-9]+(?:\\.[0-9]+)?").match(metrics_[key].toString());
    values<<(match.hasMatch()?match.captured():QString());
   }
   const auto data=(values.join(',')+"\n").toUtf8();
   if(logFile_.write(data)!=data.size() || !logFile_.flush())stopLogging();
  }
  metrics_["_elapsedMs"]=historyClock_.elapsed();
  history_.append(metrics_);trimHistory();
  emit updated();
 }
 void scanGames(){
  bool steamVr=false;
  const auto home=QDir::homePath();QStringList roots={home+"/.local/share/Steam",home+"/.steam/steam",home+"/snap/steam/common/.local/share/Steam",home+"/.var/app/com.valvesoftware.Steam/.local/share/Steam"};
  const auto clients=roots;QMap<QString,QString> owners;for(const auto &root:clients)owners[root]=root;
  for(const auto &root:clients){auto matches=QRegularExpression("\"path\"\\s+\"([^\"]+)\"").globalMatch(read(root+"/steamapps/libraryfolders.vdf"));while(matches.hasNext()){auto library=matches.next().captured(1);roots<<library;owners[library]=root;}}
  roots.removeDuplicates();QStringList ids;
  for(const auto &root:roots)for(const auto &file:QDir(root+"/steamapps").entryList({"appmanifest_*.acf"},QDir::Files)){
   QString text=read(root+"/steamapps/"+file);
   auto capture=[&](QString key){return QRegularExpression("\""+key+"\"\\s+\"([^\"]*)\"").match(text).captured(1);};
   QString id=capture("appid"),name=capture("name");
   if(id=="250820" && (capture("StateFlags").toUInt()&4))steamVr=true;
   if(!QRegularExpression("^\\d+$").match(id).hasMatch()||name.isEmpty()||ids.contains(id)||!(capture("StateFlags").toUInt()&4))continue;
   if(name.startsWith("Proton ") || name.startsWith("Steam Linux Runtime") || name=="Steamworks Common Redistributables")continue;
   ids<<id;QString art;
   for(const auto &client:clients){QString p=client+"/appcache/librarycache/"+id+"/header.jpg";if(QFile::exists(p)){art=QUrl::fromLocalFile(p).toString();break;}}
   auto owner=owners.value(root,root);QString runtime=owner.contains("/snap/steam/")?"snap":owner.contains("/.var/app/")?"flatpak":"native";
   games_.append(QVariantMap{{"id",id},{"name",name},{"art",art},{"steamRoot",owner},{"runtime",runtime}});
  }
  systemInfo_["steamVrInstalled"]=steamVr;
 }
 QTimer timer_;QString device_,hwmon_;QVariantMap metrics_,systemInfo_;QVariantList games_,history_,displays_;qulonglong lastTotal_=0,lastIdle_=0;
};
