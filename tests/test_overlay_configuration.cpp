// SPDX-License-Identifier: GPL-3.0-or-later
#include "gamingtools.h"
#include <QTemporaryDir>
#include <cstdio>
static void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);std::exit(1);}}
int main(int argc,char **argv){
 qputenv("QT_QPA_PLATFORM","offscreen");QTemporaryDir temp;qputenv("XDG_CONFIG_HOME",temp.path().toUtf8());qputenv("REDLINE_READ_ONLY","1");QGuiApplication app(argc,argv);app.setApplicationName("redline-overlay-test");
 auto base=GamingTools::overlayConfiguration({});check(base.contains("fps=1\n") && base.contains("frame_timing=0\n") && base.contains("fps_limit=0\n"),"explicit defaults");
 QVariantMap opts{{"metrics",QVariantMap{{"fps",false},{"gpu_power",true},{"exec",true}}},{"fpsLimit",144},{"hotkey","Control_R+F12"},{"horizontal",true}};
 auto changed=GamingTools::overlayConfiguration(opts);check(changed.contains("fps=0\n") && changed.contains("gpu_power=1\n") && !changed.contains("exec="),"whitelisted metric selection");check(changed.contains("fps_limit=144\n") && changed.contains("horizontal=1\n") && changed.contains("toggle_hud=Control_R+F12\n"),"actual limiter/layout/hotkey directives");
 auto invalid=GamingTools::overlayConfiguration({{"position","top-right\nexec=bad"},{"hotkey","bad\nexec=bad"},{"fpsLimit",10000},{"fontSize",1},{"opacity",900},{"enabled",false}});check(!invalid.contains("exec=") && invalid.contains("fps_limit=240\n") && invalid.contains("font_size=12\n") && invalid.contains("background_alpha=1.00\n") && invalid.contains("no_display\n"),"validation and disabled overlay");
 GamingTools tools;tools.writeOverlay(opts);QFile file(tools.overlayConfigPath());check(file.open(QIODevice::ReadOnly) && file.readAll()==changed,"settings written to isolated runtime config");
 QFile fake(temp.path()+"/gamescope");check(fake.open(QIODevice::WriteOnly),"test executable created");fake.write("#!/bin/sh\nexit 0\n");fake.close();fake.setPermissions(QFile::ReadOwner|QFile::WriteOwner|QFile::ExeOwner);qputenv("PATH",temp.path().toUtf8()+":"+qgetenv("PATH"));
 auto recipe=tools.recipe({{"gamescope",true},{"overlay",false},{"fpsLimit",60}},"native");check(recipe.contains("gamescope -f -r 60 -- %command%"),"per-game Gamescope limiter connected");
 auto scaling=tools.recipe({{"gamescope",true},{"renderSize","1280x720"},{"outputSize","1920x1080"},{"scaler","integer"},{"filter","fsr"}},"native");check(scaling.contains("-w 1280 -h 720") && scaling.contains("-W 1920 -H 1080") && scaling.contains("-S integer") && scaling.contains("-F fsr"),"Gamescope scaling arguments");
 auto rejected=tools.recipe({{"gamescope",true},{"renderSize","1920x1080;bad"},{"scaler","integer;bad"},{"filter","fsr;bad"}},"native");check(!rejected.contains("bad") && !rejected.contains("-S ") && !rejected.contains("-F "),"Gamescope scaling allowlist");
 puts("Overlay configuration: PASS (metric flags, presets primitives, limiter, hotkey, validation, persisted file)");
}
