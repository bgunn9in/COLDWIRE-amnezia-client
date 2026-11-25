#ifndef RELAYADMINUICONTROLLER_H
#define RELAYADMINUICONTROLLER_H

#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QVariantList>

#ifdef Q_OS_ANDROID
#include <QTemporaryDir>
#include <memory>
#endif

class RelayAdminUiController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool usesDocumentPicker READ usesDocumentPicker CONSTANT)
    Q_PROPERTY(bool installed READ installed NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QStringList fingerprints READ fingerprints NOTIFY changed)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit RelayAdminUiController(QObject *parent = nullptr);

    bool available() const;
    bool usesDocumentPicker() const;
    bool installed() const;
    bool busy() const;
    QStringList fingerprints() const;
    QVariantList devices() const;
    QString error() const;

    Q_INVOKABLE void request(const QString &action, const QVariantMap &arguments = {});

signals:
    void changed();
    void operationCompleted(const QString &action);

private:
    void start(QJsonObject request, const QByteArray &key = {});
    void handleReply(const QByteArray &response);
    void finish(const QString &error = {}, bool completed = true);

    const QString m_statePath;
#ifdef Q_OS_ANDROID
    bool stageDocuments(QJsonObject &request);
    std::unique_ptr<QTemporaryDir> m_documents;
    QString m_outputName;
    QString m_outputPath;
#else
    const QString m_helperPath;
    QProcess m_process;
    QByteArray m_response;
    QJsonObject m_request;
#endif
    QString m_action;
    QString m_error;
    QStringList m_fingerprints;
    QVariantList m_devices;
    bool m_installed = false;
    bool m_busy = false;
};

#endif
