#ifndef SPAADMISSION_H
#define SPAADMISSION_H

#include <QTimer>
#include <QUdpSocket>
#include <functional>

#if defined(Q_OS_WIN) || (defined(Q_OS_MACOS) && !defined(MACOS_NE))
#define AMNEZIA_DESKTOP_SPA
#endif

class SpaAdmission : public QObject
{
public:
    explicit SpaAdmission(QObject *parent = nullptr);
    void request(const QHostAddress &host, quint16 port, const QByteArray &key, std::function<void(bool)> finished);
    void cancel();

private:
    void receive();
    void complete(bool success);

    QUdpSocket m_socket;
    QTimer m_timeout;
    QHostAddress m_host;
    quint16 m_port = 0;
    QByteArray m_key;
    QByteArray m_body;
    bool m_authorizing = false;
    std::function<void(bool)> m_finished;
};

#endif
