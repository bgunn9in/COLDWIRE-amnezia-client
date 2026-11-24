pragma Singleton

import QtQuick

QtObject {
    readonly property string consoleFont: Qt.platform.os === "windows" ? "Consolas"
                                                                        : Qt.platform.os === "osx" ? "Menlo" : "monospace"

    property QtObject color: QtObject {
        readonly property color transparent: 'transparent'

        readonly property color textPrimary: '#E6F1F5'
        readonly property color textSecondary: '#CADCE4'
        readonly property color textTertiary: '#A5BAC5'
        readonly property color textQuaternary: '#8FA1B5'
        readonly property color textInverted: '#070D13'
        readonly property color textAccent: '#66DBB2'
        readonly property color textInfoInverse: '#0369A1'
        readonly property color textStaticWhite: '#FFFFFF'

        readonly property color bgBase: '#070D13'
        readonly property color bgSurface: '#0E1922'
        readonly property color bgSurfaceAlt: '#142631'
        readonly property color bgSheet: '#142631'
        readonly property color bgPanel: '#1B303D'
        readonly property color bgPanelAlt: '#294452'
        readonly property color bgOverlay: '#8009090B'
        readonly property color bgStateLayer: '#14FAFAFA'
        readonly property color bgStateLayerPressed: '#1AFAFAFA'
        readonly property color bgStateLayerAccent: '#1466DBB2'
        readonly property color bgSurfaceInverse: '#E4E4E7'
        readonly property color bgSurfaceInverseAlt: '#D4D4D8'
        readonly property color bgControlTrack: '#142631'
        readonly property color bgField: '#142631'
        readonly property color bgSelected: '#142631'
        readonly property color bgAccentSubtle: '#3966DBB2'
        readonly property color bgStaticWhite: '#FFFFFF'

        readonly property color bgAction: '#E4E4E7'
        readonly property color bgActionHover: '#D4D4D8'
        readonly property color bgActionPress: '#A1A1AA'

        readonly property color borderFaint: '#223543'
        readonly property color borderSoft: '#2D4653'
        readonly property color borderMedium: '#527385'
        readonly property color borderBold: '#8FA1B5'
        readonly property color borderEmphasis: '#E6F1F5'
        readonly property color borderAccent: '#66DBB2'
        readonly property color borderField: '#527385'
        readonly property color borderFocus: '#67B7FF'

        readonly property color accentLight: '#66DBB2'
        readonly property color accentDefault: '#66DBB2'
        readonly property color accentDark: '#28534D'
        readonly property color accentDeep: '#123432'

        readonly property color statusDestructive: '#FF929C'
        readonly property color statusWarning: '#FFC675'
        readonly property color statusSuccess: '#66DBB2'
        readonly property color statusConnecting: '#67B7FF'
        readonly property color statusIdle: '#8FA1B5'
        readonly property color connectAction: '#15535D'
        readonly property color connectActionBorder: '#528D9E'

        readonly property color promoRecommendation: '#A78BFA'
        readonly property color promoUpdate: '#38BDF8'
        readonly property color promoOverlay: '#148B5CF6'
        readonly property color promoPink: '#DB2777'
        readonly property color promoPinkDeep: '#9D174D'

        readonly property color iconDefault: '#E4E4E7'
        readonly property color iconSecondary: '#A1A1AA'
        readonly property color iconTertiary: '#2D4653'
        readonly property color iconInverted: '#09090B'

        readonly property color shadowLayer1: '#26000000'
        readonly property color shadowLayer2: '#4D000000'
        readonly property color shadowGlow: '#66DBB2'
    }
}
