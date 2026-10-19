// SPDX-License-Identifier: GPL-3.0-or-later
#include "systemintegration.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QElapsedTimer>
#include <QThread>
#include <cstdio>
static void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);std::exit(1);}}
int main(int argc,char **argv){
 QCoreApplication app(argc,argv);QTemporaryDir temp;auto path=temp.path()+"/wivrn-dashboard";auto marker=temp.path()+"/started";QFile script(path);check(script.open(QIODevice::WriteOnly),"fixture created");script.write(("#!/bin/sh\nprintf launched > '"+marker+"'\n").toUtf8());script.close();script.setPermissions(QFile::ReadOwner|QFile::WriteOwner|QFile::ExeOwner);qputenv("PATH",temp.path().toUtf8()+":"+qgetenv("PATH"));
 check(SystemIntegration::compatibility("ubuntu","26.10","x86_64")=="OS version not listed by AMD","unsupported Ubuntu rejected");
 check(SystemIntegration::compatibility("ubuntu","26.04","x86_64").contains("require verification"),"OS family never implies full compatibility");
 check(SystemIntegration::compatibility("ubuntu","26.04","aarch64")=="Architecture not listed","architecture checked");
 check(SystemIntegration::compatibility("debian","26.04","x86_64").contains("not validated"),"distribution checked");
 SystemIntegration integration;check(integration.vr().value("wivrn-dashboard").toString()==path,"installed dashboard detection");check(!QFile::exists(marker),"discovery does not start VR");check(!integration.launchVR("untrusted"),"unknown launcher rejected");check(integration.launchVR("WiVRn"),"explicit known launcher works");
 QElapsedTimer elapsed;elapsed.start();while(!QFile::exists(marker) && elapsed.elapsed()<3000){QCoreApplication::processEvents();QThread::msleep(5);}check(QFile::exists(marker),"dashboard was launched");
 while(integration.driver().value("packages")=="Checking installed packages…" && elapsed.elapsed()<4000){QCoreApplication::processEvents();QThread::msleep(5);}check(!integration.driver().value("os").toString().isEmpty(),"system identity detected");
 puts("Driver/VR integration: PASS (OS and architecture gating, detection, no automatic VR start, allowlisted explicit launch)");
}
