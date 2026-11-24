import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import ContainersModelFilters 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    property var apiAvailableProtocols: []
    property string apiCurrentProtocol: ""

    readonly property bool isApiProtocolSelectionVisible: ServersUiController.isDefaultServerFromApi && root.apiAvailableProtocols.length > 0
    readonly property bool isOutdatedAwgWarningVisible: ServersUiController.defaultServerHasOutdatedAwgContainer

    function updateApiProtocolState() {
        if (ServersUiController.isDefaultServerFromApi) {
            root.apiAvailableProtocols = SubscriptionUiController.availableProtocols(ServersUiController.defaultServerId)
            root.apiCurrentProtocol = SubscriptionUiController.currentProtocol(ServersUiController.defaultServerId)
        } else {
            root.apiAvailableProtocols = []
            root.apiCurrentProtocol = ""
        }
    }

    function openServerInfo() {
        ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)

        if (ServersUiController.isServerFromApi(ServersUiController.processedServerId)) {
            if (ServersUiController.isServerCountrySelectionAvailable(ServersUiController.processedServerId)) {
                PageController.goToPage(PageEnum.PageSettingsApiAvailableCountries)
            } else {
                PageController.showBusyIndicator(true)
                let result = SubscriptionUiController.getAccountInfo(ServersUiController.processedServerId, false)
                PageController.showBusyIndicator(false)
                if (!result) {
                    return
                }

                PageController.goToPage(PageEnum.PageSettingsApiServerInfo)
            }
        } else {
            PageController.goToPage(PageEnum.PageSettingsServerInfo)
        }
    }

    function openProtocolSelection() {
        if (ConnectionController.isConnectionInProgress) {
            PageController.showNotificationMessage(qsTr("Unable change protocol while trying to make an active connection"))
            return
        }
        if (ConnectionController.isConnected) {
            PageController.showNotificationMessage(qsTr("Cannot change protocol during active connection"))
            return
        }
        protocolSelectionDrawer.open()
    }

    function protocolDisplayName(protocol) {
        switch (protocol) {
        case "awg": return "AmneziaWG"
        case "vless": return "VLESS"
        default: return protocol || ""
        }
    }

    Component.onCompleted: {
        root.updateApiProtocolState()
    }

    Connections {
        target: ServersUiController

        function onDefaultServerIdChanged() {
            root.updateApiProtocolState()
        }
    }

    Connections {
        target: PageController

        function onRestorePageHomeState(isContainerInstalled) {
            drawer.open()
            if (isContainerInstalled) {
                containersSheet.open()
            }
        }
    }

    FlickableType {
        anchors.top: parent.top
        anchors.topMargin: PageController.safeAreaTopMargin

        contentWidth: width
        contentHeight: homeContent.implicitHeight

        ColumnLayout {
            id: homeContent

            width: parent.width
            spacing: 12

            HomeBrandHeader {
                Layout.fillWidth: true
            }

            HomeInfoButton {
                Layout.alignment: Qt.AlignHCenter
                visible: SettingsController.isLoggingEnabled
                largeText: true
                text: qsTr("Logging enabled")

                onClicked: PageController.goToPage(PageEnum.PageSettingsLogging)
            }

            HomeInfoButton {
                Layout.alignment: Qt.AlignHCenter
                visible: SettingsController.isDevModeEnabled && SettingsController.isDevGatewayEnv
                largeText: true
                text: qsTr("Dev gateway enabled")

                onClicked: PageController.goToPage(PageEnum.PageDevMenu)
            }

            ConnectButton {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                columns: root.width >= 532 ? 2 : 1
                uniformCellWidths: true
                columnSpacing: 10
                rowSpacing: 8

                HomeCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    overline: qsTr("Profile")
                    text: ServersUiController.defaultServerName
                    subtitle: {
                        const description = ServersUiController.defaultServerDescriptionCollapsed
                        const entry = ServersUiController.defaultServerEntryHost
                        if (entry && description.includes(" | ")) {
                            return description.substring(0, description.lastIndexOf(" | ")) + "\n" + qsTr("Entry %1").arg(entry)
                        }
                        return description.replace(" | ", "\n")
                    }
                    trailingIconSource: "qrc:/images/controls/chevron-down.svg"

                    onClicked: drawer.open()
                }

                HomeCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property bool siteSplitEnabled: IpSplitTunnelingController.isSplitTunnelingEnabled
                    readonly property bool directSites: siteSplitEnabled && IpSplitTunnelingController.routeMode === 2
                    readonly property bool splitEnabled: siteSplitEnabled || AppSplitTunnelingController.isSplitTunnelingEnabled
                                                         || ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling

                    overline: qsTranslate("HomeSplitTunnelingDrawer", "Split tunneling")
                    text: siteSplitEnabled ? (directSites ? qsTranslate("PageSettingsSplitTunneling", "Directly")
                                                          : qsTranslate("PageSettingsSplitTunneling", "Via VPN"))
                                           : (splitEnabled ? qsTranslate("HomeSplitTunnelingDrawer", "Enabled")
                                                           : qsTranslate("HomeSplitTunnelingDrawer", "Disabled"))
                    subtitle: siteSplitEnabled ? qsTr("Listed sites") : ""
                    titleColor: directSites ? AmneziaStyle.color.statusWarning : AmneziaStyle.color.textPrimary
                    trailingIconSource: "qrc:/images/controls/chevron-right.svg"

                    onClicked: homeSplitTunnelingDrawer.open()
                }
            }

            NotificationType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                visible: root.isOutdatedAwgWarningVisible
                variant: NotificationType.Warning
                text: qsTranslate("HomeServerSummary", "AmneziaWG 2.0 is outdated and no longer supported. Continued use requires a fresh installation of the AmneziaWG 3.1 container.")
            }

            PromoBanner {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                visible: ServersUiController.isAdVisible
                text: ServersUiController.adHeader
                subtitle: ServersUiController.adDescription

                onClicked: Qt.openUrlExternally(ServersUiController.serverAdEndpoint(ServersUiController.defaultServerId))
            }

            Item {
                Layout.preferredHeight: 8
            }
        }
    }

    HomeSplitTunnelingDrawer {
        id: homeSplitTunnelingDrawer
    }

    SheetType {
        id: drawer

        bottomY: root.height
        borderColor: AmneziaStyle.color.borderSoft
        grabberTopMargin: 16
        expandedHeight: Qt.platform.os !== "ios" ? root.height * 0.9 : screen.height * 0.77

        Item {
            anchors.fill: parent

            HomeServerSummary {
                id: expandedSummary

                anchors.left: parent.left
                anchors.right: parent.right

                expanded: true
                protocolSelectionVisible: root.isApiProtocolSelectionVisible
                protocolSelectable: root.apiAvailableProtocols.length > 1
                protocolText: root.protocolDisplayName(root.apiAvailableProtocols.length > 1 ? root.apiCurrentProtocol : root.apiAvailableProtocols[0])

                onServerInfoRequested: root.openServerInfo()
                onProtocolSelectionRequested: root.openProtocolSelection()
            }

            ColumnLayout {
                id: serversMenuHeader

                anchors.top: expandedSummary.bottom
                anchors.right: parent.right
                anchors.left: parent.left

                spacing: 0

                ButtonType {
                    id: containersDropDown

                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width - 32
                    Layout.topMargin: 16

                    visible: !ServersUiController.isDefaultServerFromApi

                    text: ServersUiController.defaultServerDefaultContainerName
                    rightImageSource: "qrc:/images/controls/chevron-down.svg"

                    onClicked: containersSheet.open()
                }

                BodyTextType {
                    Layout.fillWidth: true
                    Layout.topMargin: containersDropDown.visible ? 24 : 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    text: qsTr("Servers")
                    color: AmneziaStyle.color.textTertiary
                }
            }

            ServersListView {
                id: serversMenuContent

                anchors.top: serversMenuHeader.bottom
                anchors.right: parent.right
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.topMargin: 12

                onServerSettingsOpened: drawer.close()
            }
        }
    }

    SheetType {
        id: containersSheet

        expandedHeight: windowHeight * 0.9

        ColumnLayout {
            anchors.fill: parent

            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                IconButtonType {
                    x: 4
                    y: 0
                    icon.source: "qrc:/images/controls/arrow-left.svg"
                    Accessible.name: qsTr("Back")

                    onClicked: containersSheet.close()
                }
            }

            SectionHeaderType {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 32

                headerText: qsTr("VPN protocol")
                descriptionText: qsTr("Select an installed protocol or add a new one")
            }

            HomeContainersListView {
                id: containersListView

                Layout.fillWidth: true
                Layout.fillHeight: true

                bottomMargin: 16 + PageController.safeAreaBottomMargin

                onActivated: containersSheet.close()

                Connections {
                    target: ServersUiController

                    function onDefaultServerIdChanged() {
                        containersListView.updateContainersModelFilters()
                    }
                }

                function updateContainersModelFilters() {
                    if (ServersUiController.isServerHasWriteAccess(ServersUiController.defaultServerId)) {
                        proxyDefaultServerContainersModel.filters = ContainersModelFilters.getWriteAccessProtocolsListFilters()
                    } else {
                        proxyDefaultServerContainersModel.filters = ContainersModelFilters.getReadAccessProtocolsListFilters()
                    }
                }

                model: SortFilterProxyModel {
                    id: proxyDefaultServerContainersModel
                    sourceModel: DefaultServerContainersModel

                    sorters: [
                        RoleSorter { roleName: "isInstalled"; sortOrder: Qt.DescendingOrder }
                    ]
                }

                Component.onCompleted: updateContainersModelFilters()
            }
        }
    }

    SheetType {
        id: protocolSelectionDrawer

        expandedHeight: Math.min(windowHeight * 0.9,
                                 48 + 16 + protocolDrawerHeader.implicitHeight + 32
                                 + protocolDrawerListView.contentHeight + protocolDrawerListView.bottomMargin)

        ColumnLayout {
            id: protocolDrawerContainer

            anchors.fill: parent

            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                IconButtonType {
                    id: protocolDrawerBackButton

                    x: 4
                    y: 0
                    icon.source: "qrc:/images/controls/arrow-left.svg"
                    Accessible.name: qsTr("Back")

                    onClicked: protocolSelectionDrawer.close()
                }
            }

            SectionHeaderType {
                id: protocolDrawerHeader

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 32

                headerText: qsTr("VPN protocol")
            }

            ListViewType {
                id: protocolDrawerListView

                Layout.fillWidth: true
                Layout.fillHeight: true

                leftMargin: 16
                rightMargin: 16
                bottomMargin: 16 + PageController.safeAreaBottomMargin

                model: root.apiAvailableProtocols

                delegate: RadioItemType {
                    id: protocolDrawerRadioButton

                    width: protocolDrawerListView.width - protocolDrawerListView.leftMargin - protocolDrawerListView.rightMargin

                    showSeparator: index < protocolDrawerListView.count - 1

                    text: root.protocolDisplayName(modelData)

                    checked: modelData === root.apiCurrentProtocol

                    onClicked: {
                        protocolSelectionDrawer.close()

                        if (modelData === root.apiCurrentProtocol) {
                            return
                        }

                        if (ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Cannot change protocol during active connection"))
                            return
                        }

                        PageController.showBusyIndicator(true)
                        ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)
                        SubscriptionUiController.setCurrentProtocol(ServersUiController.defaultServerId, modelData)
                        if (!SubscriptionUiController.updateServiceFromGateway(ServersUiController.defaultServerId, "", "", true)) {
                            SubscriptionUiController.setCurrentProtocol(ServersUiController.defaultServerId, root.apiCurrentProtocol)
                        }
                        root.updateApiProtocolState()
                        PageController.showBusyIndicator(false)
                    }
                }
            }
        }
    }
}
