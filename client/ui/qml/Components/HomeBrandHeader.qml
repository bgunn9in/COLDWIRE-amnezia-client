import QtQuick
import QtQuick.Layouts

import Style 1.0

import "../Controls2/TextTypes"

Rectangle {
    id: root

    implicitHeight: 56
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: AmneziaStyle.color.accentDeep }
        GradientStop { position: 0.7; color: AmneziaStyle.color.bgSurface }
    }

    Repeater {
        model: Math.floor(root.width / 20)
        Rectangle {
            required property int index

            x: (index + 1) * 20
            width: 1
            height: root.height
            color: Qt.alpha(AmneziaStyle.color.statusConnecting, 0.05)
        }
    }

    Repeater {
        model: Math.floor(root.height / 20)
        Rectangle {
            required property int index

            y: (index + 1) * 20
            width: root.width
            height: 1
            color: Qt.alpha(AmneziaStyle.color.statusConnecting, 0.05)
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: AmneziaStyle.color.borderSoft
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        spacing: 8

        Image {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            source: "qrc:/images/coldwireMark.png"
            fillMode: Image.PreserveAspectFit
        }

        H3TextType {
            Layout.fillWidth: true
            text: Qt.application.displayName
            font.family: AmneziaStyle.consoleFont
            font.letterSpacing: 2
        }
    }
}
