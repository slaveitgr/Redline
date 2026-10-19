// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QVariantMap>
#include <QSysInfo>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QProcess>
#include <QDesktopServices>
#include <QUrl>
#include <QTimer>
class SystemIntegration final:public QObject {
 Q_OBJECT
 Q_PROPERTY(QVariantMap driver READ driver NOTIFY changed)
 Q_PROPERTY(QVariantMap vr READ vr NOTIFY changed)
 Q_PROPERTY(QString message READ message NOTIFY changed)
 public:
 ~SystemIntegration(){for(auto p:findChildren<QProcess*>(QString(),Qt::FindDirectChildrenOnly)){disconnect(p,nullptr,this,nullptr);if(p->state()!=QProcess::NotRunning){p->kill();p->waitForFinished(500);}}}
 explicit SystemIntegration(QObject *parent=nullptr):QObject(parent){refresh();}
 QVariantMap driver()const{return driver_;}QVariantMap vr()const{return vr_;}QString message()const{return message_;}
 static QString compatibility(QString distro,QString version,QString architecture){
  if(architecture!="x86_64")return "Architecture not listed";
  if(distro!="ubuntu")return "Distribution not validated by this catalog";
  if(version!="24.04" && version!="26.04")return "OS version not listed by AMD";
  return "OS family listed; point release and GPU require verification";
 }
 Q_INVOKABLE void refresh(){
  driver_={{"os",QSysInfo::prettyProductName()},{"kernel",QSysInfo::kernelVersion()},{"architecture",QSysInfo::currentCpuArchitecture()},{"release","26.16"},{"released","2026-10-05"},{"verified","2026-10-20"},{"supported","Ubuntu 24.04.5 HWE / Ubuntu 26.04.1"},{"status",compatibility(QSysInfo::productType(),QSysInfo::productVersion(),QSysInfo::currentCpuArchitecture())},{"packages","Checking installed packages…"}};
  QVariantList devices;QDir drm("/sys/class/drm");for(const auto &card:drm.entryList({"card[0-9]*"},QDir::Dirs)){
   auto base=drm.filePath(card+"/device");if(!QFile::exists(base+"/vendor"))continue;
   devices.append(QVariantMap{{"card",card},{"vendor",read(base+"/vendor")},{"device",read(base+"/device")},{"driver",QFileInfo(QFileInfo(base+"/driver").symLinkTarget()).fileName()}});
  }driver_["devices"]=devices;
  vr_.clear();for(const auto &name:QStringList{"alvr_dashboard","alvr_launcher","wivrn-dashboard","wivrn-server"})vr_[name]=QStandardPaths::findExecutable(name);
  vr_["wivrnFlatpak"]=flatpakInstalled("io.github.wivrn.wivrn");emit changed();
  if(packagesPending_)return;auto exe=QStandardPaths::findExecutable("dpkg-query");if(exe.isEmpty()){driver_["packages"]="Package version detection unavailable";emit changed();return;}
  packagesPending_=true;auto p=new QProcess(this);
  connect(p,&QProcess::finished,this,[this,p](int){packagesPending_=false;QStringList lines;for(const auto &line:QString::fromUtf8(p->readAllStandardOutput()).split('\n')){auto parts=line.split('\t');if(parts.size()==3 && parts[1].trimmed()=="installed")lines<<parts[0]+" · "+parts[2].trimmed();}driver_["packages"]=lines.isEmpty()?"No tracked graphics packages detected":lines.join("\n");p->deleteLater();emit changed();});
  connect(p,&QProcess::errorOccurred,this,[this,p](QProcess::ProcessError e){if(e==QProcess::FailedToStart){packagesPending_=false;driver_["packages"]="Package version detection unavailable";p->deleteLater();emit changed();}});
  QTimer::singleShot(3000,p,[p]{if(p->state()!=QProcess::NotRunning)p->kill();});
  p->start(exe,{"-W","-f=${binary:Package}\t${db:Status-Status}\t${Version}\n","libgl1-mesa-dri","mesa-vulkan-drivers","amdgpu-install","amdgpu-dkms","vulkan-amdgpu-pro"});
 }
 Q_INVOKABLE bool openReference(QString key){
  const QMap<QString,QString> urls{{"amd","https://www.amd.com/en/support/download/linux-drivers.html"},{"release","https://www.amd.com/en/resources/support-articles/release-notes/RN-AMDGPU-UNIFIED-LINUX-26-16.html"},{"alvr","https://github.com/alvr-org/ALVR/wiki/Installation-guide"},{"wivrn","https://github.com/WiVRn/WiVRn#Getting-started"}};
  return urls.contains(key) && QDesktopServices::openUrl(QUrl(urls.value(key)));
 }
 Q_INVOKABLE bool launchVR(QString backend){
  QString exe;QStringList args;
  if(backend=="ALVR"){exe=QStandardPaths::findExecutable("alvr_dashboard");if(exe.isEmpty())exe=QStandardPaths::findExecutable("alvr_launcher");}
  else if(backend=="WiVRn"){exe=QStandardPaths::findExecutable("wivrn-dashboard");if(exe.isEmpty() && flatpakInstalled("io.github.wivrn.wivrn")){exe=QStandardPaths::findExecutable("flatpak");args={"run","io.github.wivrn.wivrn"};}}
  if(exe.isEmpty()){message_="VR dashboard not installed or not detected.";emit changed();return false;}
  bool ok=QProcess::startDetached(exe,args);message_=ok?"VR dashboard launched. Pair the headset in that application.":"Could not launch the VR dashboard.";emit changed();return ok;
 }
 private:
 QVariantMap driver_,vr_;QString message_;bool packagesPending_=false;
 static QString read(QString path){QFile f(path);return f.open(QIODevice::ReadOnly)?QString::fromUtf8(f.readAll()).trimmed():QString();}
 static bool flatpakInstalled(const QString &id){
  if(QStandardPaths::findExecutable("flatpak").isEmpty())return false;
  for(const auto &root:QStringList{QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)+"/flatpak/app/","/var/lib/flatpak/app/"}){
   QDir app(root+id);for(auto arch:app.entryList(QDir::Dirs|QDir::NoDotAndDotDot))for(auto branch:QDir(app.filePath(arch)).entryList(QDir::Dirs|QDir::NoDotAndDotDot))if(QFile::exists(app.filePath(arch+"/"+branch+"/active/metadata")))return true;
  }return false;
 }
 signals:void changed();
};
