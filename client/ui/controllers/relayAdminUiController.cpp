#include "relayAdminUiController.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRandomGenerator>
#include <QStandardPaths>
#include <utility>

#include "secureQSettings.h"

#ifdef Q_OS_ANDROID
    #include <QDir>
    #include <QFile>
    #include <QFutureWatcher>
    #include <QtConcurrent>
    #include "platforms/android/android_controller.h"
    #include "platforms/android/android_utils.h"
    #include "systemController.h"
#endif

#ifdef Q_OS_WIN
    #include <qt_windows.h>
#endif

namespace
{
const auto keychainService = QStringLiteral("COLDWIRE relay administration");
const auto keychainEntry = QStringLiteral("operator encryption key");
constexpr auto replyLimit = 2 * 1024 * 1024;

QString operatorStatePath()
{
#ifdef Q_OS_ANDROID
    const auto directory = AndroidUtils::getActivity().callObjectMethod("getNoBackupFilesDir", "()Ljava/io/File;");
    const auto root = directory.callObjectMethod("getAbsolutePath", "()Ljava/lang/String;").toString();
#else
    const auto root = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
#endif
    return root.isEmpty() ? QString() : root + QStringLiteral("/coldwire-operator.bin");
}

#ifdef Q_OS_ANDROID
constexpr auto androidBridge = "org/amnezia/vpn/relayadmin/RelayAdmin";
constexpr auto documentLimit = 32 * 1024 * 1024;
#else
QString helperPath()
{
#if defined(Q_OS_WIN)
    return QCoreApplication::applicationDirPath() + QStringLiteral("/coldwire-admin-helper.exe");
#elif defined(Q_OS_MACOS) || defined(Q_OS_LINUX)
    return QCoreApplication::applicationDirPath() + QStringLiteral("/coldwire-admin-helper");
#else
    return {};
#endif
}
#endif

} // namespace

RelayAdminUiController::RelayAdminUiController(QObject *parent)
    : QObject(parent),
      m_statePath(operatorStatePath()),
#ifndef Q_OS_ANDROID
      m_helperPath(helperPath()),
#endif
      m_installed(QFileInfo::exists(m_statePath))
{
#ifndef Q_OS_ANDROID
#ifdef Q_OS_WIN
    m_process.setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments *arguments) {
        arguments->flags |= CREATE_NO_WINDOW;
    });
#endif
    connect(&m_process, &QProcess::started, this, [this] {
        m_process.write(QJsonDocument(m_request).toJson(QJsonDocument::Compact));
        m_request = {};
        m_process.closeWriteChannel();
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        m_process.readAllStandardError();
    });
    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this] {
        m_response.append(m_process.readAllStandardOutput());
        if (m_response.size() > replyLimit) {
            m_process.kill();
        }
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            finish(tr("Could not start COLDWIRE administration."));
        }
    });
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        m_response.append(m_process.readAllStandardOutput());
        const auto response = std::exchange(m_response, {});
        handleReply(status == QProcess::NormalExit && code == 0 ? response : QByteArray{});
    });
#endif
}

bool RelayAdminUiController::available() const
{
    if (m_statePath.isEmpty()) {
        return false;
    }
#ifdef Q_OS_ANDROID
    QJniEnvironment env;
    const auto bridge = env.findClass(androidBridge);
    env.checkAndClearExceptions();
    return bridge != nullptr;
#else
    return !m_helperPath.isEmpty() && QFileInfo(m_helperPath).isExecutable();
#endif
}

bool RelayAdminUiController::usesDocumentPicker() const
{
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
}

bool RelayAdminUiController::installed() const { return m_installed; }
bool RelayAdminUiController::busy() const { return m_busy; }
QStringList RelayAdminUiController::fingerprints() const { return m_fingerprints; }
QVariantList RelayAdminUiController::devices() const { return m_devices; }
QString RelayAdminUiController::error() const { return m_error; }

void RelayAdminUiController::request(const QString &action, const QVariantMap &arguments)
{
    if (!available() || m_busy) {
        return;
    }
    m_action = action;
    m_busy = true;
    m_error.clear();
    if (action == QStringLiteral("preflight")) {
        m_fingerprints.clear();
    }
    emit changed();
    auto request = QJsonObject::fromVariantMap(arguments);
    request.insert(QStringLiteral("action"), action);
    if (action == QStringLiteral("preflight")) {
        start(std::move(request));
        return;
    }

    auto *read = new QKeychain::ReadPasswordJob(keychainService, this);
    read->setKey(keychainEntry);
    connect(read, &QKeychain::Job::finished, this, [this, read, request = std::move(request)] {
        if (read->error() == QKeychain::NoError && read->binaryData().size() == 32) {
            start(request, read->binaryData());
            return;
        }
        if (read->error() != QKeychain::EntryNotFound || QFileInfo::exists(m_statePath)) {
            finish(tr("Could not unlock the COLDWIRE operator key."));
            return;
        }
        QByteArray key;
        for (int i = 0; i < 8; ++i) {
            const quint32 random = QRandomGenerator::system()->generate();
            key.append(reinterpret_cast<const char *>(&random), sizeof(random));
        }
        auto *write = new QKeychain::WritePasswordJob(keychainService, this);
        write->setKey(keychainEntry);
        write->setBinaryData(key);
        connect(write, &QKeychain::Job::finished, this, [this, write, request, key] {
            if (write->error() == QKeychain::NoError) {
                start(request, key);
            } else {
                finish(tr("Could not save the COLDWIRE operator key in the system key store."));
            }
        });
        write->start();
    });
    read->start();
}

void RelayAdminUiController::start(QJsonObject request, const QByteArray &key)
{
    if (!key.isEmpty()) {
        request.insert(QStringLiteral("stateKey"), QString::fromLatin1(key.toHex()));
    }
#ifdef Q_OS_ANDROID
    if (!stageDocuments(request)) {
        finish(tr("Could not open the selected document."));
        return;
    }
    const auto activity = AndroidUtils::getActivity();
    auto *job = new QFutureWatcher<QByteArray>(this);
    connect(job, &QFutureWatcher<QByteArray>::finished, this, [this, job] {
        const auto response = job->result();
        job->deleteLater();
        handleReply(response);
    });
    job->setFuture(QtConcurrent::run([activity, request = QJsonDocument(request).toJson(QJsonDocument::Compact), state = m_statePath] {
        return QJniObject::callStaticObjectMethod(androidBridge, "run",
                "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
                activity.object(), QJniObject::fromString(QString::fromUtf8(request)).object<jstring>(),
                QJniObject::fromString(state).object<jstring>()).toString().toUtf8();
    }));
#else
    m_request = std::move(request);
    m_response.clear();
    m_process.start(m_helperPath, {QStringLiteral("--state"), m_statePath});
#endif
}

void RelayAdminUiController::handleReply(const QByteArray &response)
{
    const auto reply = response.size() <= replyLimit ? QJsonDocument::fromJson(response).object() : QJsonObject{};
    if (!reply.value(QStringLiteral("ok")).toBool()) {
        finish(tr("The operation did not complete. Check SSH access and refresh the device list."));
        return;
    }
    if (reply.contains(QStringLiteral("fingerprints"))) {
        m_fingerprints.clear();
        for (const auto &number : reply.value(QStringLiteral("fingerprints")).toArray()) {
            m_fingerprints.append(number.toString());
        }
    }
    if (reply.contains(QStringLiteral("installed"))) {
        m_installed = reply.value(QStringLiteral("installed")).toBool();
    }
    if (reply.contains(QStringLiteral("devices"))) {
        m_devices = reply.value(QStringLiteral("devices")).toArray().toVariantList();
    }
#ifdef Q_OS_ANDROID
    if (!m_outputPath.isEmpty()) {
        QFile file(m_outputPath);
        if (!file.open(QIODevice::ReadOnly) || file.size() > documentLimit) {
            finish(tr("Could not read the generated document."));
            return;
        }
        const auto content = file.readAll();
        file.close();
        bool cancelled = false;
        SystemController documents;
        if (!documents.saveFile(m_outputName, content, QStringLiteral("application/octet-stream"), &cancelled)) {
            finish(cancelled ? QString() : tr("Could not save the generated document."), false);
            return;
        }
    }
#endif
    finish();
}

#ifdef Q_OS_ANDROID
bool RelayAdminUiController::stageDocuments(QJsonObject &request)
{
    const auto action = request.value(QStringLiteral("action")).toString();
    const auto output = action == QStringLiteral("export") || action == QStringLiteral("backup-operator");
    QStringList inputs;
    if (action == QStringLiteral("restore-operator")) {
        inputs << QStringLiteral("source");
    } else if (action == QStringLiteral("install")) {
        for (const auto &field : {QStringLiteral("entryKey"), QStringLiteral("exitKey")}) {
            if (!request.value(field).toString().isEmpty()) {
                inputs << field;
            }
        }
    }
    if (inputs.isEmpty() && !output) {
        return true;
    }
    const auto privateDir = QFileInfo(m_statePath).absolutePath();
    if (!QDir().mkpath(privateDir)) {
        return false;
    }
    m_documents = std::make_unique<QTemporaryDir>(privateDir + QStringLiteral("/relay-documents-XXXXXX"));
    if (!m_documents->isValid()) {
        return false;
    }
    for (const auto &field : inputs) {
        auto *android = AndroidController::instance();
        const int fd = android->getFd(request.value(field).toString());
        if (fd < 0) {
            return false;
        }
        QFile source;
        const bool opened = source.open(fd, QIODevice::ReadOnly);
        const auto contents = opened ? source.read(documentLimit + 1) : QByteArray{};
        source.close();
        android->closeFd();
        QFile target(m_documents->filePath(field));
        if (contents.isEmpty() || contents.size() > documentLimit ||
            !target.open(QIODevice::WriteOnly) || target.write(contents) != contents.size()) {
            return false;
        }
        request.insert(field, target.fileName());
    }
    if (output) {
        const auto suffix = action == QStringLiteral("export") ? QStringLiteral(".vpn") : QStringLiteral(".cwoperator");
        m_outputName = QFileInfo(request.value(QStringLiteral("output")).toString()).fileName();
        if (!m_outputName.endsWith(suffix, Qt::CaseInsensitive)) {
            return false;
        }
        m_outputPath = m_documents->filePath(QStringLiteral("export") + suffix);
        request.insert(QStringLiteral("output"), m_outputPath);
    }
    return true;
}
#endif

void RelayAdminUiController::finish(const QString &error, bool completed)
{
#ifdef Q_OS_ANDROID
    m_outputPath.clear();
    m_outputName.clear();
    m_documents.reset();
#else
    m_request = {};
#endif
    m_busy = false;
    m_error = error;
    emit changed();
    if (completed && error.isEmpty()) {
        emit operationCompleted(m_action);
    }
}
