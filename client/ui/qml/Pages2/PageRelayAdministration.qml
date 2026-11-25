import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "../Components"
import "../Controls2"
import "../Controls2/TextTypes"

PageType {
    id: root

    property string checkedEntry
    property string checkedExit
    property string entryKey
    property string exitKey
    property string selectedDevice
    property string selectedUser
    property string selectedState
    property string confirmation
    property bool revokeUser: false
    property bool creatingDevice: false
    property string initialRouting: "ru-services"
    property string newDeviceRouting: "ru-services"

    readonly property var routingModes: [
        {value: "ru-services", label: qsTr("Selected Russian services directly")},
        {value: "ru-direct", label: qsTr("Extended Russian list directly")},
        {value: "all", label: qsTr("All sites through the VPN")}
    ]

    readonly property bool busy: RelayAdminController.busy
    readonly property bool installed: RelayAdminController.installed
    readonly property bool endpointsConfirmed: checkedEntry === entryAddress.textField.text
                                                && checkedExit === exitAddress.textField.text
                                                && RelayAdminController.fingerprints.length === 2

    function refresh() {
        RelayAdminController.request("list")
    }

    function outputFile(title, filter, suggestedName, suffix) {
        return RelayAdminController.usesDocumentPicker ? suggestedName
                                                       : SystemController.getFileName(title, filter, suggestedName, true, suffix)
    }

    Connections {
        target: RelayAdminController

        function onOperationCompleted(action) {
            if (action === "install" || action === "attach" || action === "restore-operator" || action === "add" || action.startsWith("pause")
                    || action.startsWith("resume") || action.startsWith("revoke")) {
                root.refresh()
            }
            if (action === "add") {
                root.creatingDevice = false
            } else if (action === "export") {
                PageController.showNotificationMessage(qsTr("Profile saved"))
            } else if (action === "backup-operator") {
                PageController.showNotificationMessage(qsTr("Operator backup saved"))
            } else if (action === "list") {
                const row = RelayAdminController.devices.find(device => device.id === root.selectedDevice)
                root.selectedDevice = row ? row.id : ""
                root.selectedState = row ? row.state : ""
            }
        }
    }

    Component.onCompleted: {
        if (root.installed) {
            root.refresh()
        }
    }

    FlickableType {
        anchors.top: parent.top
        contentHeight: content.implicitHeight

        ColumnLayout {
            id: content

            width: parent.width
            spacing: 12

            NavigationBarType {
                Layout.fillWidth: true
                title: qsTr("COLDWIRE administration")
            }

            HomeBrandHeader {
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 10

                BodyTextType {
                    Layout.fillWidth: true
                    visible: root.busy
                    text: qsTr("Working on the selected operation…")
                }

                NotificationType {
                    Layout.fillWidth: true
                    visible: RelayAdminController.error !== ""
                    variant: NotificationType.Warning
                    text: RelayAdminController.error
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !root.installed
                    enabled: !root.busy
                    spacing: 10

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 500 ? 2 : 1
                        uniformCellWidths: true
                        columnSpacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true

                            H3TextType { text: qsTr("Entry server A") }
                            TextFieldType {
                                id: entryAddress
                                Layout.fillWidth: true
                                headerText: qsTr("SSH address")
                                placeholderText: "192.0.2.10:22"
                            }
                            TextFieldType {
                                id: entryUser
                                Layout.fillWidth: true
                                headerText: qsTr("SSH user")
                                textField.text: "root"
                            }
                            TextFieldType {
                                id: entryPassword
                                Layout.fillWidth: true
                                headerText: root.entryKey === "" ? qsTr("SSH password") : qsTr("SSH key passphrase")
                                passwordToggle: true
                            }
                            ButtonType {
                                Layout.fillWidth: true
                                variant: ButtonType.Secondary
                                text: root.entryKey === "" ? qsTr("Use an SSH key") : qsTr("Use password instead")
                                onClicked: {
                                    root.entryKey = root.entryKey === "" ? SystemController.getFileName(qsTr("Open SSH private key"),
                                                                                                      qsTr("All files (*)"), "", false, "") : ""
                                    entryPassword.textField.clear()
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true

                            H3TextType { text: qsTr("Exit server B") }
                            TextFieldType {
                                id: exitAddress
                                Layout.fillWidth: true
                                headerText: qsTr("SSH address")
                                placeholderText: "198.51.100.20:22"
                            }
                            TextFieldType {
                                id: exitUser
                                Layout.fillWidth: true
                                headerText: qsTr("SSH user")
                                textField.text: "root"
                            }
                            TextFieldType {
                                id: exitPassword
                                Layout.fillWidth: true
                                headerText: root.exitKey === "" ? qsTr("SSH password") : qsTr("SSH key passphrase")
                                passwordToggle: true
                            }
                            ButtonType {
                                Layout.fillWidth: true
                                variant: ButtonType.Secondary
                                text: root.exitKey === "" ? qsTr("Use an SSH key") : qsTr("Use password instead")
                                onClicked: {
                                    root.exitKey = root.exitKey === "" ? SystemController.getFileName(qsTr("Open SSH private key"),
                                                                                                    qsTr("All files (*)"), "", false, "") : ""
                                    exitPassword.textField.clear()
                                }
                            }
                        }
                    }

                    ButtonType {
                        Layout.fillWidth: true
                        text: qsTr("Check SSH fingerprints")
                        enabled: entryAddress.textField.text !== "" && exitAddress.textField.text !== ""
                        onClicked: {
                            root.checkedEntry = entryAddress.textField.text
                            root.checkedExit = exitAddress.textField.text
                            RelayAdminController.request("preflight", {entry: root.checkedEntry, exit: root.checkedExit})
                        }
                    }

                    BodyTextType {
                        Layout.fillWidth: true
                        visible: root.endpointsConfirmed
                        wrapMode: Text.WrapAnywhere
                        text: visible ? "A " + RelayAdminController.fingerprints[0] + "\nB " + RelayAdminController.fingerprints[1] : ""
                    }

                    H3TextType { text: qsTr("Routing for the first device") }
                    Repeater {
                        model: root.routingModes
                        RadioItemType {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.label
                            checked: root.initialRouting === modelData.value
                            onClicked: root.initialRouting = modelData.value
                        }
                    }

                    ButtonType {
                        Layout.fillWidth: true
                        text: qsTr("Trust fingerprints and install")
                        enabled: root.endpointsConfirmed && entryUser.textField.text !== "" && exitUser.textField.text !== ""
                                 && (root.entryKey !== "" || entryPassword.textField.text !== "")
                                 && (root.exitKey !== "" || exitPassword.textField.text !== "")
                        onClicked: {
                            RelayAdminController.request("install", {
                                entry: root.checkedEntry,
                                exit: root.checkedExit,
                                entryUser: entryUser.textField.text,
                                exitUser: exitUser.textField.text,
                                entryPassword: root.entryKey === "" ? entryPassword.textField.text : "",
                                exitPassword: root.exitKey === "" ? exitPassword.textField.text : "",
                                entryKey: root.entryKey,
                                exitKey: root.exitKey,
                                entryKeyPassphrase: root.entryKey === "" ? "" : entryPassword.textField.text,
                                exitKeyPassphrase: root.exitKey === "" ? "" : exitPassword.textField.text,
                                routing: root.initialRouting,
                                entryFingerprint: RelayAdminController.fingerprints[0],
                                exitFingerprint: RelayAdminController.fingerprints[1]
                            })
                            entryPassword.textField.clear()
                            exitPassword.textField.clear()
                        }
                    }

                    TextFieldType {
                        id: existingFolder
                        Layout.fillWidth: true
                        visible: !RelayAdminController.usesDocumentPicker
                        headerText: qsTr("Existing operator folder")
                    }

                    ButtonType {
                        Layout.fillWidth: true
                        visible: !RelayAdminController.usesDocumentPicker
                        text: qsTr("Attach existing relay")
                        variant: ButtonType.Secondary
                        enabled: existingFolder.textField.text !== ""
                        onClicked: RelayAdminController.request("attach", {operatorFolder: existingFolder.textField.text})
                    }
                }

                TextFieldType {
                    id: backupPassword
                    Layout.fillWidth: true
                    headerText: qsTr("Operator backup passphrase")
                    passwordToggle: true
                    enabled: !root.busy
                }

                ButtonType {
                    Layout.fillWidth: true
                    variant: ButtonType.Secondary
                    text: root.installed ? qsTr("Back up operator access") : qsTr("Restore operator access")
                    enabled: !root.busy && backupPassword.textField.text.length >= 12
                    onClicked: {
                        const filter = qsTr("Operator backup (*.cwoperator)")
                        const path = root.installed ? root.outputFile(text, filter, "operator.cwoperator", "cwoperator")
                                                    : SystemController.getFileName(text, filter, "", false, "cwoperator")
                        if (path !== "") {
                            const password = backupPassword.textField.text
                            backupPassword.textField.clear()
                            if (root.installed) {
                                RelayAdminController.request("backup-operator", {output: path, passphrase: password})
                            } else {
                                RelayAdminController.request("restore-operator", {source: path, passphrase: password})
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.installed
                    enabled: !root.busy
                    spacing: 8

                    H3TextType { text: qsTr("Users and devices") }

                    Repeater {
                        model: RelayAdminController.devices

                        HomeCard {
                            required property var modelData
                            Layout.fillWidth: true
                            overline: modelData.user
                            text: modelData.id
                            subtitle: {
                                if (modelData.state === "paused") return qsTr("Paused")
                                if (modelData.pendingOn === "entry") return qsTr("Operation awaiting A")
                                if (modelData.pendingOn === "exit") return qsTr("Operation awaiting B")
                                return qsTr("Active")
                            }
                            onClicked: {
                                root.selectedDevice = modelData.id
                                root.selectedUser = modelData.user
                                root.selectedState = modelData.state
                                root.confirmation = ""
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.selectedDevice !== ""
                        spacing: 8

                        BodyTextType {
                            Layout.fillWidth: true
                            text: root.selectedUser + " · " + root.selectedDevice
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            spacing: 8

                            ButtonType {
                                text: qsTr("Save .vpn")
                                enabled: root.selectedState === "active"
                                onClicked: {
                                    const file = root.outputFile(qsTr("Save profile"), qsTr("VPN profile (*.vpn)"),
                                                                 root.selectedDevice + ".vpn", "vpn")
                                    if (file !== "") {
                                        RelayAdminController.request("export", {device: root.selectedDevice, output: file})
                                    }
                                }
                            }
                            ButtonType {
                                text: qsTr("Pause device")
                                variant: ButtonType.Secondary
                                onClicked: RelayAdminController.request("pause", {device: root.selectedDevice})
                            }
                            ButtonType {
                                text: qsTr("Resume device")
                                variant: ButtonType.Secondary
                                onClicked: RelayAdminController.request("resume", {device: root.selectedDevice})
                            }
                            ButtonType {
                                text: qsTr("Pause user")
                                variant: ButtonType.Secondary
                                onClicked: RelayAdminController.request("pause-user", {device: root.selectedUser})
                            }
                            ButtonType {
                                text: qsTr("Resume user")
                                variant: ButtonType.Secondary
                                onClicked: RelayAdminController.request("resume-user", {device: root.selectedUser})
                            }
                            ButtonType {
                                text: qsTr("Delete device")
                                variant: ButtonType.Destructive
                                onClicked: {
                                    root.revokeUser = false
                                    root.confirmation = root.selectedDevice
                                }
                            }
                            ButtonType {
                                text: qsTr("Delete user")
                                variant: ButtonType.Destructive
                                onClicked: {
                                    root.revokeUser = true
                                    root.confirmation = root.selectedUser
                                }
                            }
                        }

                        ButtonType {
                            Layout.fillWidth: true
                            visible: root.confirmation !== ""
                            variant: ButtonType.Destructive
                            text: root.revokeUser ? qsTr("Revoke every device for %1").arg(root.confirmation)
                                                  : qsTr("Revoke device %1").arg(root.confirmation)
                            onClicked: {
                                RelayAdminController.request(root.revokeUser ? "revoke-user" : "revoke", {device: root.confirmation})
                                root.confirmation = ""
                            }
                        }
                    }

                    ButtonType {
                        Layout.fillWidth: true
                        variant: ButtonType.Secondary
                        text: qsTr("Refresh")
                        onClicked: root.refresh()
                    }

                    ButtonType {
                        Layout.fillWidth: true
                        visible: !root.creatingDevice
                        text: qsTr("Add user or device")
                        onClicked: root.creatingDevice = true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.creatingDevice

                        TextFieldType {
                            id: newUser
                            Layout.fillWidth: true
                            headerText: qsTr("User name")
                        }
                        TextFieldType {
                            id: newDevice
                            Layout.fillWidth: true
                            headerText: qsTr("Device name")
                        }
                        H3TextType { text: qsTr("Site routing") }
                        Repeater {
                            model: root.routingModes
                            RadioItemType {
                                required property var modelData
                                Layout.fillWidth: true
                                text: modelData.label
                                checked: root.newDeviceRouting === modelData.value
                                onClicked: root.newDeviceRouting = modelData.value
                            }
                        }
                        ButtonType {
                            Layout.fillWidth: true
                            text: qsTr("Create profile")
                            enabled: /^[A-Za-z0-9][A-Za-z0-9_-]{0,47}$/.test(newDevice.textField.text)
                                     && /^[A-Za-z0-9][A-Za-z0-9_-]{0,47}$/.test(newUser.textField.text)
                            onClicked: {
                                root.selectedDevice = newDevice.textField.text
                                root.selectedUser = newUser.textField.text
                                RelayAdminController.request("add", {user: newUser.textField.text, device: newDevice.textField.text,
                                                                    routing: root.newDeviceRouting})
                            }
                        }
                    }
                }
            }
        }
    }
}
