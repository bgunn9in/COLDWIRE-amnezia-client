#include "ipSplitTunnelingUiController.h"

#include <QDebug>
#include <QFile>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>

#include "amneziaApplication.h"
#include "systemController.h"
#include "core/utils/errorCodes.h"
#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"
#include "core/utils/ruSiteList.h"

IpSplitTunnelingUiController::IpSplitTunnelingUiController(IpSplitTunnelingController* ipSplitTunnelingController,
                                                          IpSplitTunnelingModel* ipSplitTunnelingModel, QObject *parent)
    : QObject(parent),
      m_ipSplitTunnelingController(ipSplitTunnelingController),
      m_ipSplitTunnelingModel(ipSplitTunnelingModel)
{
    m_ipSplitTunnelingModel->updateModel(m_ipSplitTunnelingController->getCurrentSites());
}

void IpSplitTunnelingUiController::addSite(QString hostname)
{
    if (m_ipSplitTunnelingController->addSite(hostname)) {
        emit finished(tr("New site added: %1").arg(hostname));
    }
}

void IpSplitTunnelingUiController::removeSite(int index)
{
    auto modelIndex = m_ipSplitTunnelingModel->index(index);
    auto hostname = m_ipSplitTunnelingModel->data(modelIndex, IpSplitTunnelingModel::Roles::UrlRole).toString();
    if (m_ipSplitTunnelingController->removeSite(hostname)) {
        emit finished(tr("Site removed: %1").arg(hostname));
    }
}

void IpSplitTunnelingUiController::removeSites()
{
    m_ipSplitTunnelingController->removeSites();
    emit finished(tr("Site list cleared!"));
}

void IpSplitTunnelingUiController::importSites(const QString &fileName, bool replaceExisting)
{
    QByteArray jsonData;
    if (!SystemController::readFile(fileName, jsonData)) {
        emit errorOccurred(tr("Can't open file: %1").arg(fileName));
        return;
    }

    QString errorMessage;
    if (m_ipSplitTunnelingController->importSitesFromJson(jsonData, replaceExisting, errorMessage)) {
        emit finished(tr("Import completed"));
    } else {
        emit errorOccurred(errorMessage);
    }
}

void IpSplitTunnelingUiController::exportSites(const QString &fileName)
{
    QByteArray jsonData = m_ipSplitTunnelingController->exportSitesToJson();
    if (!SystemController::saveFile(fileName, jsonData)) {
        qInfo() << "IpSplitTunnelingUiController::exportSites: save or share was cancelled or failed";
        return;
    }
    emit finished(tr("Export completed"));
}

void IpSplitTunnelingUiController::loadRussianSites(bool expanded)
{
    if (m_russianSitesLoading) {
        return;
    }
    m_pendingRussianSites.clear();
    m_russianSitesLoading = true;
    emit russianSitesLoadingChanged();

    const QString fileName = expanded ? "ru-direct.amnezia.json" : "ru-services.amnezia.json";
    QNetworkRequest request{ QUrl("https://raw.githubusercontent.com/bgunn9in/coldwire/refs/heads/ru-lists/" + fileName) };
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    request.setTransferTimeout(15000);
    auto *reply = amnApp->networkManager()->get(request);
    reply->setReadBufferSize(ruSiteList::maxBytes + 1);
    QTimer::singleShot(15000, reply, [reply]() {
        if (!reply->isFinished()) {
            reply->abort();
        }
    });
    connect(reply, &QNetworkReply::readyRead, this, [reply]() {
        if (reply->bytesAvailable() > ruSiteList::maxBytes) {
            reply->abort();
        }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, fileName, expanded]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError
            && reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 200
            && reply->bytesAvailable() <= ruSiteList::maxBytes) {
            m_pendingRussianSites = ruSiteList::parse(reply->readAll(), expanded);
        }
        const bool bundled = m_pendingRussianSites.isEmpty();
        if (bundled) {
            QFile file(":/site-lists/" + fileName);
            if (file.open(QIODevice::ReadOnly)) {
                m_pendingRussianSites = ruSiteList::parse(file.read(ruSiteList::maxBytes + 1), expanded);
            }
        }
        m_russianSitesLoading = false;
        emit russianSitesLoadingChanged();
        if (m_pendingRussianSites.isEmpty()) {
            emit errorOccurred(tr("Could not load the Russian site list."));
        } else {
            emit russianSitesReady(expanded, bundled);
        }
    });
}

void IpSplitTunnelingUiController::applyRussianSites()
{
    if (m_russianSitesLoading || m_pendingRussianSites.isEmpty()) {
        return;
    }
    m_ipSplitTunnelingController->replaceDirectSites(m_pendingRussianSites);
    m_pendingRussianSites.clear();
    emit routeModeChanged();
    emit isSplitTunnelingEnabledChanged();
    emit finished(tr("Russian site list applied."));
}

bool IpSplitTunnelingUiController::russianSitesLoading() const
{
    return m_russianSitesLoading;
}

void IpSplitTunnelingUiController::toggleSplitTunneling(bool enabled)
{
    m_ipSplitTunnelingController->toggleSplitTunneling(enabled);
    emit isSplitTunnelingEnabledChanged();
}

void IpSplitTunnelingUiController::setRouteMode(int routeMode)
{
    m_ipSplitTunnelingController->setRouteMode(static_cast<amnezia::RouteMode>(routeMode));
    emit routeModeChanged();
}

int IpSplitTunnelingUiController::getRouteMode() const
{
    return static_cast<int>(m_ipSplitTunnelingController->getRouteMode());
}

bool IpSplitTunnelingUiController::isSplitTunnelingEnabled() const
{
    return m_ipSplitTunnelingController->isSplitTunnelingEnabled();
}

void IpSplitTunnelingUiController::updateModel()
{
    m_ipSplitTunnelingModel->updateModel(m_ipSplitTunnelingController->getCurrentSites());
}
