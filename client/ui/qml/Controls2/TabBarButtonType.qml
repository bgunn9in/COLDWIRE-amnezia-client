import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import Style 1.0

import "TextTypes"

TabButton {
    id: root

    property bool showBadge: false
    property bool horizontal: false

    implicitWidth: root.horizontal ? content.implicitWidth + 20 : Math.max(56, Math.min(78, label.implicitWidth + 10))
    implicitHeight: root.horizontal ? 44 : 52
    width: implicitWidth
    height: implicitHeight

    hoverEnabled: true
    padding: 0
    icon.color: root.checked ? AmneziaStyle.color.accentLight : AmneziaStyle.color.iconDefault

    Accessible.name: root.text

    background: Item {
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 2
            color: AmneziaStyle.color.accentLight
            visible: root.checked
        }

        FocusRingType {
            radius: 2
            visible: root.visualFocus
        }
    }

    contentItem: Item {
        GridLayout {
            id: content

            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            columns: root.horizontal ? 2 : 1
            columnSpacing: 6
            rowSpacing: 2

            IconImage {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: root.icon.source
                sourceSize: Qt.size(18, 18)
                color: root.icon.color

                DotBadgeType {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    visible: root.showBadge
                    color: AmneziaStyle.color.accentLight
                }
            }

            CaptionTextType {
                id: label

                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.text
                color: root.checked ? AmneziaStyle.color.accentLight : AmneziaStyle.color.textTertiary
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Keys.onEnterPressed: {
        root.checked = true
        root.clicked()
    }

    Keys.onReturnPressed: {
        root.checked = true
        root.clicked()
    }
}
