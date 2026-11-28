#include <QFile>
#include <QTest>

#include "../core/utils/ruSiteList.h"

class TestRuSiteLists : public QObject
{
    Q_OBJECT

private slots:
    void bundledLists()
    {
        QFile services(":/site-lists/ru-services.amnezia.json");
        QFile direct(":/site-lists/ru-direct.amnezia.json");
        QVERIFY(services.open(QIODevice::ReadOnly));
        QVERIFY(direct.open(QIODevice::ReadOnly));
        QCOMPARE(ruSiteList::parse(services.readAll(), false).size(), 77);
        const QByteArray full = direct.readAll();
        QCOMPARE(ruSiteList::parse(full, true).size(), 1097);
        QVERIFY(ruSiteList::parse(full, false).isEmpty());
    }

    void invalidLists()
    {
        const QByteArray entry = R"({"hostname":"direct-192-168-0-0-16.invalid","ip":"192.168.0.0/16"})";
        const QByteArray valid = "[" + entry + "]";
        QCOMPARE(ruSiteList::parse(valid, false).size(), 1);
        QVERIFY(ruSiteList::parse(R"({"error": true})", false).isEmpty());
        QVERIFY(ruSiteList::parse("[]", false).isEmpty());
        QVERIFY(ruSiteList::parse("[" + entry + ",{}]", false).isEmpty());
        QVERIFY(ruSiteList::parse("[" + entry + "," + entry + "]", false).isEmpty());
        QVERIFY(ruSiteList::parse(QByteArray(valid).replace("192.168.0.0", "192.168.1.1"), false).isEmpty());
        QVERIFY(ruSiteList::parse(QByteArray(valid).replace("/16", "/48"), false).isEmpty());
        QVERIFY(ruSiteList::parse(QByteArray(valid).replace("192.168.0.0/16", "::/64"), false).isEmpty());
        QVERIFY(ruSiteList::parse(R"([{"hostname":"direct-0-0-0-0-0.invalid","ip":"0.0.0.0/0"}])", false).isEmpty());
        QVERIFY(ruSiteList::parse(valid + QByteArray(ruSiteList::maxBytes, ' '), false).isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestRuSiteLists)

#include "testRuSiteLists.moc"
