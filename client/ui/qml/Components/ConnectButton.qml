import QtQuick
import QtQuick.Controls.impl
import QtQuick.Layouts

import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"

Item {
    id: root

    property bool wide: width >= 500
    readonly property bool connected: ConnectionController.isConnected
    readonly property bool inProgress: ConnectionController.isConnectionInProgress
    readonly property bool failed: ConnectionController.hasConnectionError
    readonly property color stateColor: {
        if (root.inProgress) return AmneziaStyle.color.statusConnecting
        if (root.connected) return AmneziaStyle.color.statusSuccess
        if (root.failed) return AmneziaStyle.color.statusDestructive
        return AmneziaStyle.color.statusIdle
    }

    implicitHeight: Math.max(root.wide ? 120 : 144, contents.implicitHeight + 28)

    Rectangle {
        anchors.fill: parent
        radius: 2
        topRightRadius: 14
        border.color: AmneziaStyle.color.borderSoft
        border.width: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.tint(AmneziaStyle.color.bgSurface, Qt.alpha(root.stateColor, 0.09))
            }
            GradientStop { position: 0.68; color: AmneziaStyle.color.bgSurface }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: 2
            color: root.stateColor
        }
    }

    GridLayout {
        id: contents

        anchors.fill: parent
        anchors.margins: 14
        columns: root.wide ? 2 : 1
        columnSpacing: 14
        rowSpacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 2
                topRightRadius: 8
                border.color: Qt.tint(AmneziaStyle.color.borderSoft, Qt.alpha(root.stateColor, 0.5))
                border.width: 1
                color: Qt.tint(AmneziaStyle.color.bgBase, Qt.alpha(root.stateColor, 0.1))

                IconImage {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    color: root.stateColor
                    source: {
                        if (root.inProgress) return "qrc:/images/controls/refresh-cw.svg"
                        if (root.connected) return "qrc:/images/controls/check.svg"
                        if (root.failed) return "qrc:/images/controls/alert-triangle.svg"
                        return "qrc:/images/controls/radio.svg"
                    }
                }
            }

            H3TextType {
                Layout.fillWidth: true
                text: root.failed ? qsTr("Connection error")
                                  : root.connected || root.inProgress ? ConnectionController.connectionStateText
                                                                     : qsTranslate("VpnProtocol", "Disconnected")
                color: root.stateColor
                font.family: AmneziaStyle.consoleFont
                font.pixelSize: root.wide ? 23 : 18
                wrapMode: Text.Wrap
            }
        }

        ButtonType {
            id: action

            Layout.fillWidth: !root.wide
            visible: !root.inProgress || ConnectionController.canCancelConnection
            variant: ButtonType.Secondary
            text: {
                if (root.inProgress) return qsTranslate("PageSettingsSplitTunneling", "Cancel")
                if (root.connected) return qsTranslate("SystemTrayNotificationHandler", "Disconnect")
                if (root.failed) return qsTranslate("PageUpdate", "Retry")
                return ConnectionController.connectionStateText
            }

            background: Rectangle {
                radius: 2
                topRightRadius: 8
                border.width: 1
                border.color: root.inProgress || root.connected || root.failed
                              ? Qt.tint(AmneziaStyle.color.borderSoft, Qt.alpha(root.stateColor, 0.55))
                              : AmneziaStyle.color.connectActionBorder
                color: {
                    const base = root.inProgress || root.connected || root.failed
                              ? Qt.tint(AmneziaStyle.color.bgSurface, Qt.alpha(root.stateColor, 0.10))
                              : AmneziaStyle.color.connectAction
                    return action.down ? Qt.darker(base, 1.2) : action.hovered ? Qt.lighter(base, 1.2) : base
                }

                FocusRingType {
                    radius: 2
                    visible: action.visualFocus
                }
            }

            onClicked: ConnectionController.connectButtonClicked()
        }
    }
}
