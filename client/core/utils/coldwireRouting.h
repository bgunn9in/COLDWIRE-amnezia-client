#ifndef COLDWIREROUTING_H
#define COLDWIREROUTING_H

#include <QHostAddress>
#include <QJsonArray>
#include <QJsonObject>

namespace amnezia::coldwireRouting
{

inline constexpr int profileFormatVersion = 2;
inline const QString field = QStringLiteral("coldwireRouting");

inline bool isValid(const QJsonObject &policy)
{
    const auto version = policy.value(QStringLiteral("version"));
    const auto mode = policy.value(QStringLiteral("mode")).toString();
    const auto networks = policy.value(QStringLiteral("ipv4"));
    if (policy.size() != 3 || version.toInt(-1) != 1 || !networks.isArray()) {
        return false;
    }
    const auto prefixes = networks.toArray();
    if (mode == QStringLiteral("all")) {
        return prefixes.isEmpty();
    }
    if ((mode != QStringLiteral("ru-services") && mode != QStringLiteral("ru-direct")) ||
        prefixes.isEmpty() || prefixes.size() > 2048) {
        return false;
    }
    for (const auto &value : prefixes) {
        const auto [address, prefix] = QHostAddress::parseSubnet(value.toString());
        if (address.protocol() != QAbstractSocket::IPv4Protocol || prefix < 1 ||
            address.toString() + QStringLiteral("/") + QString::number(prefix) != value.toString()) {
            return false;
        }
    }
    return true;
}

} // namespace amnezia::coldwireRouting

#endif
