#include <QGuiApplication>
#include <QTemporaryDir>
#include <QFile>
#include <QCryptographicHash>
#include "gamingtools.h"
int main(int argc,char**argv){QTemporaryDir temp;qputenv("QT_QPA_PLATFORM","offscreen");qputenv("XDG_CONFIG_HOME",temp.path().toUtf8());qputenv("REDLINE_READ_ONLY","1");QGuiApplication app(argc,argv);app.setApplicationName("redline-overlay-isolation-test");GamingTools tools;auto preview=tools.overlayConfigPath();if(!preview.startsWith(temp.path()+"/") || !preview.endsWith("/preview/MangoHud.conf"))return 1;qunsetenv("REDLINE_READ_ONLY");auto normal=tools.overlayConfigPath();QFile original(normal);QByteArray before;if(original.open(QIODevice::ReadOnly))before=original.readAll();bool existed=original.exists();original.close();qputenv("REDLINE_READ_ONLY","1");tools.writeOverlay({{"enabled",false},{"fontSize",24}});QFile result(preview);if(!result.open(QIODevice::ReadOnly)||!result.readAll().contains("no_display"))return 2;QByteArray after;if(original.open(QIODevice::ReadOnly))after=original.readAll();if(before!=after || existed!=original.exists())return 3;qInfo("PASS: preview overlay is isolated; normal configuration unchanged");}
