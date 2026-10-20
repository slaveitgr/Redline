// SPDX-License-Identifier: GPL-3.0-or-later
#include "shortcutsupport.h"
#include <QGuiApplication>
#include <cstdio>
int main(int argc,char **argv){qputenv("QT_QPA_PLATFORM","offscreen");QGuiApplication app(argc,argv);ShortcutSupport helper;
 for(const auto &text:{"Ctrl+Shift+R","Alt+G","F12"})if(helper.canonical(text).isEmpty())return 1;
 for(const auto &text:{"R","Shift+R","Ctrl+Delete","Esc","Ctrl+R, Ctrl+L","not-a-shortcut"})if(!helper.canonical(text).isEmpty()){fprintf(stderr,"Accepted invalid shortcut: %s\n",text);return 2;}
 if(helper.canonical("ctrl+shift+r")!="Ctrl+Shift+R")return 3;
 puts("Shortcut validation: PASS");}
