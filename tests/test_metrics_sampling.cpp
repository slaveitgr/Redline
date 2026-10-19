#include <QGuiApplication>
#include <QEventLoop>
#include <QTemporaryDir>
#include <QTextStream>
#include "nativedashboard.h"
static void wait(int ms){QEventLoop loop;QTimer::singleShot(ms,&loop,&QEventLoop::quit);loop.exec();}
int main(int argc,char**argv){
 QTemporaryDir temp;qputenv("XDG_DATA_HOME",temp.path().toUtf8());qputenv("QT_QPA_PLATFORM","offscreen");QGuiApplication app(argc,argv);app.setApplicationName("redline-sampling-test");
 NativeDashboard dashboard;
 auto check=[](bool okay,const char *message){if(!okay){qCritical("FAIL: %s",message);exit(1);}};
 check(dashboard.samplingIntervalMs()==1000,"default sampling");
 dashboard.configureSampling(-1,0);check(dashboard.samplingIntervalMs()==250 && dashboard.historyDurationSeconds()==10,"bounded sampling settings");
 wait(11200);auto history=dashboard.history();check(history.size()>=30 && history.size()<=42,"time bounded history at 250ms");
 auto first=history.first().toMap()["_elapsedMs"].toLongLong();auto last=history.last().toMap()["_elapsedMs"].toLongLong();check(last-first<=10000 && last-first>=9000,"ten second graph window");
 for(int i=1;i<history.size();i++)check(history[i].toMap()["_elapsedMs"].toLongLong()>history[i-1].toMap()["_elapsedMs"].toLongLong(),"monotonic timestamps");
 dashboard.configureSampling(500,10);check(dashboard.startLogging(),"create CSV");wait(1700);auto path=dashboard.loggingPath();dashboard.stopLogging();QFile csv(path);check(csv.open(QIODevice::ReadOnly),"read CSV");auto rows=csv.readAll().trimmed().split('\n');check(rows.size()>=3 && rows.size()<=5,"CSV follows sampling interval");for(auto row:rows)check(row.split(',').size()==8,"CSV schema retained");
 dashboard.configureSampling(99999,99999);check(dashboard.samplingIntervalMs()==5000 && dashboard.historyDurationSeconds()==120,"upper bounds");
 qInfo("PASS: interval limits, real timer, monotonic history retention and CSV cadence");
}
