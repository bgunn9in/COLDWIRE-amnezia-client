#include "ruSiteList.h"

#include <QHostAddress>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

QMap<QString, QStringList> ruSiteList::parse(const QByteArray &json, bool expanded)
{
    if (json.isEmpty() || json.size() > maxBytes) {
        return {};
    }
    const QJsonDocument document = QJsonDocument::fromJson(json);
    const auto entries = document.array();
    if (entries.isEmpty() || entries.size() > (expanded ? 2010 : 1000)) {
        return {};
    }

    QMap<QString, QStringList> sites;
    for (const auto &entry : entries) {
        const auto row = entry.toObject();
        const QString ip = row.value("ip").toString();
        const auto [address, prefix] = QHostAddress::parseSubnet(ip);
        if (address.protocol() != QAbstractSocket::IPv4Protocol || prefix <= 0 || prefix > 32) {
            return {};
        }
        const QString addressText = address.toString();
        const QString canonicalIp = addressText + '/' + QString::number(prefix);
        const QString hostname = QString("direct-%1-%2.invalid").arg(QString(addressText).replace('.', '-')).arg(prefix);
        if (ip != canonicalIp || row.value("hostname").toString() != hostname || sites.contains(hostname)) {
            return {};
        }
        sites.insert(hostname, { ip });
    }
    return sites;
}
