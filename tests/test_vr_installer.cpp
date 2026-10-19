// SPDX-License-Identifier: GPL-3.0-or-later
#include "vrinstaller.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QFile>
#include <QElapsedTimer>
#include <QThread>
#include <cstdio>
static void check(bool ok,const char *text){if(!ok){fprintf(stderr,"FAIL: %s\n",text);std::exit(1);}}
static void settle(VrInstaller &installer){QElapsedTimer clock;clock.start();while(installer.busy() && clock.elapsed()<5000){QCoreApplication::processEvents();QThread::msleep(1);}check(!installer.busy(),"installer completed");}
int main(int argc,char **argv){QCoreApplication app(argc,argv);QTemporaryDir temp;auto log=temp.path()+"/args";QFile script(temp.path()+"/flatpak");check(script.open(QIODevice::WriteOnly),"fixture created");script.write(("#!/bin/sh\nif [ \"$1\" = remotes ]; then\n if [ \"$REDLINE_TEST_REMOTE\" = bad ]; then printf 'flathub\\thttps://example.com/repo/\\n'; elif [ \"$REDLINE_TEST_REMOTE\" != system ] || [ \"$2\" = --system ]; then printf 'flathub\\thttps://dl.flathub.org/repo/\\n'; fi\nelse printf '%s\\n' \"$*\" >> '"+log+"'; fi\n").toUtf8());script.close();script.setPermissions(QFile::ReadOwner|QFile::WriteOwner|QFile::ExeOwner);qputenv("PATH",temp.path().toUtf8()+":"+qgetenv("PATH"));VrInstaller installer;int installed=0;QObject::connect(&installer,&VrInstaller::installed,&app,[&]{++installed;});
 qputenv("REDLINE_READ_ONLY","1");installer.install("WiVRn");check(!installer.busy() && !QFile::exists(log),"preview never installs");qunsetenv("REDLINE_READ_ONLY");installer.install("unknown");check(!installer.busy(),"unknown backend blocked");
 installer.install("WiVRn");settle(installer);check(installed==1,"explicit install completed");QFile args(log);check(args.open(QIODevice::ReadOnly) && args.readAll().contains("install --user --noninteractive --assumeyes flathub io.github.wivrn.wivrn"),"user remote chosen and fixed app installed");args.close();
 qputenv("REDLINE_TEST_REMOTE","system");installer.install("WiVRn");settle(installer);check(installed==2,"system remote fallback");check(args.open(QIODevice::ReadOnly) && args.readAll().contains("install --system"),"system remote scope matched");args.close();
 qputenv("REDLINE_TEST_REMOTE","bad");installer.install("WiVRn");settle(installer);check(installed==2 && installer.message().contains("not configured"),"untrusted source never installed");
 puts("VR installer: PASS (preview guard, explicit request, user/system scope, fixed app/source, unsupported source)");}
