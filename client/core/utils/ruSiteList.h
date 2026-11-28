#pragma once

#include <QByteArray>
#include <QMap>
#include <QString>
#include <QStringList>

namespace ruSiteList
{
    inline constexpr qsizetype maxBytes = 256 * 1024;

    QMap<QString, QStringList> parse(const QByteArray &json, bool expanded);
}
