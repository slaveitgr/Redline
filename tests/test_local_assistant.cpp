// SPDX-License-Identifier: GPL-3.0-or-later
#include "localassistant.h"
#include <QCoreApplication>
#include <QTcpServer>
#include <QTcpSocket>
#include <QElapsedTimer>
#include <QThread>
#include <cstdio>
static bool waitFor(const std::function<bool()> &condition){QElapsedTimer t;t.start();while(!condition() && t.elapsed()<5000){QCoreApplication::processEvents();QThread::msleep(1);}return condition();}
int main(int argc,char **argv){
 QCoreApplication app(argc,argv);QTcpServer server;
 if(!server.listen(QHostAddress::LocalHost,11434)){fprintf(stderr,"Test requires an unused local port 11434; existing service was left unchanged.\n");return 77;}
 QString mode="models";QJsonObject requestBody;int requests=0;
 QObject::connect(&server,&QTcpServer::newConnection,&app,[&]{
  auto *socket=server.nextPendingConnection();auto buffer=std::make_shared<QByteArray>();
  QObject::connect(socket,&QTcpSocket::disconnected,socket,&QObject::deleteLater);
  QObject::connect(socket,&QTcpSocket::readyRead,&app,[&,socket,buffer]{
   *buffer+=socket->readAll();int split=buffer->indexOf("\r\n\r\n");if(split<0)return;
   int length=0;for(auto line:buffer->left(split).split('\n'))if(line.toLower().startsWith("content-length:"))length=line.mid(15).trimmed().toInt();if(buffer->size()<split+4+length)return;
   ++requests;requestBody=QJsonDocument::fromJson(buffer->mid(split+4,length)).object();
   if(mode=="hold")return;
   QByteArray body=mode=="models"?R"({"models":[{"name":"test-local"},{"name":"remote:cloud"},{"name":"remote-custom","remote_host":"https://example.com"}]})":mode=="invalid"?"not json":R"({"message":{"role":"assistant","content":"Test response"}})";
   socket->write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "+QByteArray::number(body.size())+"\r\nConnection: close\r\n\r\n"+body);socket->disconnectFromHost();
  });
 });
 LocalAssistant assistant;QString answer;QObject::connect(&assistant,&LocalAssistant::answered,&app,[&](QString value){answer=value;});
 auto check=[](bool ok,const char *name){if(!ok){fprintf(stderr,"FAIL: %s\n",name);std::exit(1);}};
 check(requests==0,"no automatic requests");assistant.refresh();check(waitFor([&]{return !assistant.busy();}),"model request completed");check(assistant.models()==QStringList{"test-local"},"remote models excluded");
 mode="chat";assistant.send("test-local",{QVariantMap{{"role","user"},{"content","Hello"}}},"No sensors supplied");check(waitFor([&]{return !assistant.busy();}),"chat completed");check(answer=="Test response","actual answer emitted");check(requestBody.value("stream")==false && requestBody.value("messages").toArray().last().toObject().value("content")=="Hello","valid Ollama payload");
 int before=requests;assistant.send("not-installed",{},"");check(!assistant.error().isEmpty() && requests==before,"invalid model blocked");
 mode="invalid";assistant.refresh();check(waitFor([&]{return !assistant.busy();}),"malformed response completed");check(!assistant.error().isEmpty() && assistant.models().isEmpty(),"invalid response clears stale models");
 mode="hold";assistant.refresh();check(waitFor([&]{return requests>before+1;}),"cancel test connected");assistant.cancel();check(waitFor([&]{return !assistant.busy();}) && !assistant.error().isEmpty(),"cancellation completes");
 puts("Local assistant transport: PASS (models, chat, remote filtering, malformed response, cancellation, no automatic requests)");
}
