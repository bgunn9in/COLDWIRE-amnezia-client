#include "connectionUiController.h"

#include <QElapsedTimer>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QTimer>

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS) || defined(MACOS_NE)
    #include <QGuiApplication>
#else
    #include <QApplication>
#endif

#include "amneziaApplication.h"
#include "core/controllers/serversController.h"
#include "core/models/containerConfig.h"
#include "core/utils/containerEnum.h"
#include "systemController.h"

ConnectionUiController::ConnectionUiController(ConnectionController* connectionController,
                                                ServersController* serversController,
                                                QObject *parent)
    : QObject(parent),
      m_connectionController(connectionController),
      m_serversController(serversController)
{
    connect(m_connectionController, &ConnectionController::connectionStateChanged, this, &ConnectionUiController::onConnectionStateChanged);

    connect(this, &ConnectionUiController::connectButtonClicked, this, &ConnectionUiController::toggleConnection, Qt::QueuedConnection);

    m_state = Vpn::ConnectionState::Disconnected;
}

void ConnectionUiController::openConnection()
{
    const QString serverId = m_serversController->getDefaultServerId();
    if (serverId.isEmpty()) {
        m_connectionController->setConnectionState(Vpn::ConnectionState::Disconnected);
        return;
    }

    ErrorCode errorCode = m_connectionController->openConnection(serverId);

    if (errorCode != ErrorCode::NoError) {
        notifyConnectionBlocked(errorCode);
        return;
    }
}

void ConnectionUiController::closeConnection()
{
    m_connectionController->closeConnection();
}

ErrorCode ConnectionUiController::getLastConnectionError()
{
    return m_connectionController->lastConnectionError();
}

void ConnectionUiController::exportConnectionReport(const QString &fileName)
{
    auto save = [this, fileName](const QJsonObject &report, const QString &result) {
        bool cancelled = false;
        const bool saved = SystemController::saveFile(fileName, QJsonDocument(report).toJson(),
                                                      QStringLiteral("application/json"), &cancelled);
        emit connectionReportExported(saved, cancelled, result);
    };
    auto report = m_connectionController->connectionReport();
    if (!isConnected()) {
        report.insert("https_check", "not_connected");
        save(report, tr("Connection report saved"));
        return;
    }

    auto *manager = new QNetworkAccessManager(this);
    manager->setProxy(QNetworkProxy::NoProxy);
    QNetworkRequest request(QUrl(QStringLiteral("https://github.com/")));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    QElapsedTimer elapsed;
    elapsed.start();
    auto *reply = manager->head(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, manager, report, elapsed, save]() mutable {
        QString result;
        if (reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).isValid()) {
            report.insert("https_check", "reachable");
            result = tr("Connection report saved. GitHub responded over HTTPS.");
        } else if (reply->error() == QNetworkReply::HostNotFoundError) {
            report.insert("https_check", "dns_failed");
            result = tr("Connection report saved. DNS could not resolve GitHub.");
        } else {
            report.insert("https_check", "unreachable");
            result = tr("Connection report saved. The GitHub HTTPS check failed.");
        }
        report.insert("https_elapsed_ms", elapsed.elapsed());
        manager->deleteLater();
        save(report, result);
    });
    QTimer::singleShot(6000, reply, [reply] {
        if (reply->isRunning())
            reply->abort();
    });
}

void ConnectionUiController::onConnectionStateChanged(Vpn::ConnectionState state)
{
    m_state = state;

    m_isConnected = false;
    m_connectionStateText = tr("Connecting...");
    switch (state) {
    case Vpn::ConnectionState::Connected: {
        amnApp->networkManager()->clearConnectionCache();

        m_isConnectionInProgress = false;
        m_isConnected = true;
        m_connectionStateText = tr("Connected");
        break;
    }
    case Vpn::ConnectionState::Connecting: {
        m_isConnectionInProgress = true;
        break;
    }
    case Vpn::ConnectionState::Reconnecting: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Reconnecting...");
        break;
    }
    case Vpn::ConnectionState::Disconnected: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        break;
    }
    case Vpn::ConnectionState::Disconnecting: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Disconnecting...");
        break;
    }
    case Vpn::ConnectionState::Preparing: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Preparing...");
        break;
    }
    case Vpn::ConnectionState::Error: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        emit connectionErrorOccurred(getLastConnectionError());
        break;
    }
    case Vpn::ConnectionState::Unknown: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        emit connectionErrorOccurred(getLastConnectionError());
        break;
    }
    }
    emit connectionStateChanged();
}

void ConnectionUiController::onTranslationsUpdated()
{
    onConnectionStateChanged(getCurrentConnectionState());
}

Vpn::ConnectionState ConnectionUiController::getCurrentConnectionState()
{
    return m_state;
}

QString ConnectionUiController::connectionStateText() const
{
    return m_connectionStateText;
}

void ConnectionUiController::toggleConnection()
{
    if (m_state == Vpn::ConnectionState::Preparing) {
        emit preparingConfig();
        return;
    }

    if (isConnectionInProgress()) {
        closeConnection();
    } else if (isConnected()) {
        closeConnection();
    } else {
        const QString serverId = m_serversController->getDefaultServerId();
        if (serverId.isEmpty()) {
            return;
        }

        const ErrorCode errorCode = m_connectionController->isConnectionSupported(serverId);
        if (errorCode != ErrorCode::NoError) {
            notifyConnectionBlocked(errorCode);
            return;
        }

        emit prepareConfig();
    }
}

void ConnectionUiController::notifyConnectionBlocked(ErrorCode errorCode)
{
    if (errorCode == ErrorCode::LegacyApiV1NotSupportedError) {
        emit unsupportedConnectDrawerRequested();
        return;
    }

    if (errorCode == ErrorCode::NoInstalledContainersError) {
        emit noInstalledContainers();
        return;
    }

    emit connectionErrorOccurred(errorCode);
}

bool ConnectionUiController::isConnectionInProgress() const
{
    return m_isConnectionInProgress;
}

bool ConnectionUiController::hasConnectionError() const
{
    return m_state == Vpn::ConnectionState::Error || m_state == Vpn::ConnectionState::Unknown;
}

bool ConnectionUiController::canCancelConnection() const
{
    return m_state == Vpn::ConnectionState::Connecting || m_state == Vpn::ConnectionState::Reconnecting;
}

bool ConnectionUiController::isConnected() const
{
    return m_isConnected;
}

bool ConnectionUiController::isRevokeBlockedDuringActiveConnection(const QString &serverId, int containerIndex,
                                                                   const QString &clientId) const
{
    if (clientId.isEmpty() || (!isConnected() && !isConnectionInProgress())) {
        return false;
    }

    if (m_serversController->getDefaultServerId() != serverId) {
        return false;
    }

    if (static_cast<int>(m_serversController->getDefaultContainer(serverId)) != containerIndex) {
        return false;
    }

    const auto adminConfig = m_serversController->selfHostedAdminConfig(serverId);
    if (!adminConfig.has_value()) {
        return false;
    }

    const QString connectionClientId =
            adminConfig->containerConfig(static_cast<DockerContainer>(containerIndex)).protocolConfig.clientId();
    if (connectionClientId.isEmpty()) {
        return false;
    }

    return connectionClientId == clientId || connectionClientId.contains(clientId);
}
