#include "core/models/protocols/awgProtocolConfig.h"
#include "core/utils/spaAdmission.h"

#include <QCoreApplication>
#include <QFile>
#include <QThread>
#include <QTimer>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const QJsonObject normalAwg = { { "hostName", "192.0.2.1" }, { "port", 32497 } };
    const QJsonObject spa = { { "version", 1 }, { "port", 62201 }, { "key", QString(64, u'a') } };
    auto protectedAwg = normalAwg;
    protectedAwg["coldwireSpa"] = spa;
    auto roundTrip = amnezia::AwgClientConfig::fromJson(normalAwg).toJson();
    if (!roundTrip.take("coldwireSpa").isUndefined()
        || amnezia::AwgClientConfig::fromJson(protectedAwg).toJson().value("coldwireSpa") != spa) {
        return 3;
    }
    if (argc == 1) {
        SpaAdmission admission;
        if (!admission.findChild<QUdpSocket *>() || !admission.findChild<QTimer *>()) {
            return 4;
        }
        return 0;
    }
    const auto args = app.arguments();
    if (args.size() != 4 || args[1] != QStringLiteral("127.0.0.1")) {
        return 3;
    }
    auto keyFile = QFile(args[3]);
    if (!keyFile.open(QIODevice::ReadOnly)) {
        return 3;
    }
    const auto key = QByteArray::fromHex(keyFile.readAll().trimmed());
    QThread worker;
    SpaAdmission admission;
    auto *mainThread = QThread::currentThread();
    admission.moveToThread(&worker);
    QTimer::singleShot(0, &admission, [&] {
        admission.request(QHostAddress(args[1]), args[2].toUShort(), key,
                          [&](bool confirmed) {
                              admission.moveToThread(mainThread);
                              QMetaObject::invokeMethod(&app, [&, confirmed] { app.exit(confirmed ? 0 : 2); },
                                                        Qt::QueuedConnection);
                          });
    });
    worker.start();
    const int result = app.exec();
    worker.quit();
    worker.wait();
    return result;
}
