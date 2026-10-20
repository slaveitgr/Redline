// SPDX-License-Identifier: GPL-3.0-or-later
#include "shortcutsupport.h"
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlComponent>
#include <QQuickWindow>
#include <QTest>
#include <QKeyEvent>
#include <QFileInfo>
#include <cstdio>
int main(int argc,char **argv){qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");QGuiApplication app(argc,argv);ShortcutSupport support;QQmlEngine engine;engine.rootContext()->setContextProperty("shortcutSupport",&support);
 QQmlComponent component(&engine);component.setData(R"(import QtQuick
import QtQuick.Window
Window {
 id:win;visible:true;width:200;height:100
 property int activations:0
 property string custom:"Alt+P"
 QtObject {id:store;function read(name,fallback){return win.custom}}
 RedlineShortcut {settingsStore:store;action:"metrics";defaultSequence:"Alt+P";onActivated:win.activations++}
})",QUrl::fromLocalFile(QFileInfo(QString::fromUtf8(argv[1])+"/ShortcutTest.qml").absoluteFilePath()));
 auto window=qobject_cast<QQuickWindow*>(component.create());if(!window){qWarning()<<component.errors();return 1;}window->requestActivate();QTest::qWait(150);
 QTest::keyClick(window,Qt::Key_P,Qt::AltModifier);if(window->property("activations").toInt()!=1)return 2;
 QKeyEvent repeat(QEvent::KeyPress,Qt::Key_P,Qt::AltModifier,"p",true,1);QCoreApplication::sendEvent(window,&repeat);if(window->property("activations").toInt()!=1)return 3;
 window->setProperty("custom","invalid text");QTest::qWait(20);QTest::keyClick(window,Qt::Key_P,Qt::AltModifier);if(window->property("activations").toInt()!=1)return 4;
 delete window;puts("Real QML shortcut activation, repeat suppression and invalid binding: PASS");}
