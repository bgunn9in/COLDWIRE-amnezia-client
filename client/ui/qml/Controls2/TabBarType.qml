import QtQuick
import QtQuick.Controls

import Style 1.0

TabBar {
    id: root

    spacing: width >= 500 ? 18 : 4

    topPadding: PageController.safeAreaBottomMargin > 0 ? 0 : 4
    bottomPadding: PageController.safeAreaBottomMargin > 0 ? PageController.safeAreaBottomMargin : 4
    leftPadding: 16
    rightPadding: 16

    contentItem: Item {
        implicitWidth: tabsRow.implicitWidth
        implicitHeight: tabsRow.implicitHeight

        Row {
            id: tabsRow

            anchors.centerIn: parent

            spacing: root.spacing

            Repeater {
                model: root.contentModel
            }
        }
    }

    background: Rectangle {
        color: AmneziaStyle.color.bgSurface

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            height: 1
            color: AmneziaStyle.color.borderSoft
        }
    }
}
