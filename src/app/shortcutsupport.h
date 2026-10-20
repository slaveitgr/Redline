// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QKeySequence>
class ShortcutSupport final:public QObject {
 Q_OBJECT
public:
 using QObject::QObject;
 Q_INVOKABLE QString canonical(QString text)const{
  text=text.trimmed();if(text.size()>80 || text.isEmpty())return {};
  const auto sequence=QKeySequence::fromString(text,QKeySequence::PortableText);
  if(sequence.count()!=1 || sequence.isEmpty())return {};
  const auto combination=sequence[0];const auto key=combination.key();
  if(key==Qt::Key_unknown || key==Qt::Key_Escape || key==Qt::Key_Tab || key==Qt::Key_Backspace || key==Qt::Key_Delete || key==Qt::Key_Return || key==Qt::Key_Enter)return {};
  if(!(combination.keyboardModifiers() & (Qt::ControlModifier|Qt::AltModifier)) && !(key>=Qt::Key_F1 && key<=Qt::Key_F12))return {};
  return sequence.toString(QKeySequence::PortableText);
 }
};
