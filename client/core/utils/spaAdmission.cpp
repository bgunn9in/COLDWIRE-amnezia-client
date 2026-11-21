#include "spaAdmission.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QMessageAuthenticationCode>
#include <QNetworkDatagram>
#include <QRandomGenerator>
#include <QtEndian>
#include <utility>

namespace
{
    const int bodySize = 72;
    const int frameSize = 104;
    const int nonceOffset = 20;
    const int nonceSize = 16;

    QByteArray authenticated(const QByteArray &body, const QByteArray &key)
    {
        return body + QMessageAuthenticationCode::hash(body, key, QCryptographicHash::Sha256);
    }

    bool equalTag(const QByteArray &first, const QByteArray &second)
    {
        unsigned int difference = 0;
        for (int index = bodySize; index < frameSize; ++index) {
            difference |= static_cast<unsigned char>(first[index] ^ second[index]);
        }
        return difference == 0;
    }
}

SpaAdmission::SpaAdmission(QObject *parent)
    : QObject(parent), m_socket(this), m_timeout(this)
{
    m_timeout.setSingleShot(true);
    connect(&m_timeout, &QTimer::timeout, this, [this] { complete(false); });
    connect(&m_socket, &QUdpSocket::readyRead, this, &SpaAdmission::receive);
}

void SpaAdmission::request(const QHostAddress &host, quint16 port, const QByteArray &key,
                           std::function<void(bool)> finished)
{
    cancel();
    m_finished = std::move(finished);
    if (host.protocol() != QAbstractSocket::IPv4Protocol || port == 0 || key.size() != 32
        || !m_socket.bind(QHostAddress::AnyIPv4)) {
        complete(false);
        return;
    }
    m_host = host;
    m_port = port;
    m_key = key;
    m_body = QByteArray(bodySize, '\0');
    m_body.replace(0, 4, "CWQ1");
    m_body.replace(4, 8, QCryptographicHash::hash(key, QCryptographicHash::Sha256).left(8));
    qToBigEndian<quint64>(QDateTime::currentSecsSinceEpoch(), m_body.data() + 12);
    for (int offset = nonceOffset; offset < nonceOffset + nonceSize; offset += 4) {
        qToBigEndian<quint32>(QRandomGenerator::system()->generate(), m_body.data() + offset);
    }
    m_timeout.start(4000);
    if (m_socket.writeDatagram(authenticated(m_body, m_key), m_host, m_port) != frameSize) {
        complete(false);
    }
}

void SpaAdmission::receive()
{
    while (m_finished && m_socket.hasPendingDatagrams()) {
        const QNetworkDatagram incoming = m_socket.receiveDatagram(frameSize + 1);
        const QByteArray data = incoming.data();
        if (incoming.senderAddress() != m_host || incoming.senderPort() != m_port || data.size() != frameSize) {
            continue;
        }
        if (m_authorizing) {
            QByteArray expected = m_body;
            expected.replace(0, 4, "CWO1");
            if (data.first(bodySize) == expected && equalTag(data, authenticated(expected, m_key))) {
                complete(true);
            }
            continue;
        }
        if (!data.startsWith("CWC1") || data.sliced(4, 8) != m_body.sliced(4, 8)
            || data.sliced(nonceOffset, nonceSize) != m_body.sliced(nonceOffset, nonceSize)
            || !equalTag(data, authenticated(data.first(bodySize), m_key))) {
            continue;
        }
        m_body = data.first(bodySize);
        m_body.replace(0, 4, "CWA1");
        m_authorizing = true;
        if (m_socket.writeDatagram(authenticated(m_body, m_key), m_host, m_port) != frameSize) {
            complete(false);
        }
    }
}

void SpaAdmission::cancel()
{
    m_finished = {};
    m_timeout.stop();
    m_socket.close();
    m_key.clear();
    m_body.clear();
    m_authorizing = false;
}

void SpaAdmission::complete(bool success)
{
    auto finished = std::move(m_finished);
    cancel();
    if (finished) {
        finished(success);
    }
}
