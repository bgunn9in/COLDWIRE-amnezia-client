import QtQuick

import Style 1.0

import "../Controls2"

ListItemType {
    id: root

    showSeparator: false

    background: Rectangle {
        radius: 2
        topRightRadius: 10
        border.width: 1
        border.color: root.rowHovered || root.visualFocus ? AmneziaStyle.color.borderFocus : AmneziaStyle.color.borderSoft
        color: root.rowPressed ? AmneziaStyle.color.bgSurfaceAlt : AmneziaStyle.color.bgSurface

        FocusRingType {
            radius: 2
            visible: root.visualFocus
        }
    }
}
