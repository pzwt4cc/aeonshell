// Bar.qml

import "../"
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    readonly property string barMode: "primary"

    property bool specialActive: false
    readonly property var _hyKeepAlive: Hyprland.monitors

    function syncSpecialState() {
        let hasActiveSpecial = false;
        const mons = Hyprland.monitors.values;
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            const sw = m && m.lastIpcObject ? m.lastIpcObject.specialWorkspace : null;
            if (sw && ((sw.id !== undefined && sw.id !== 0) || (sw.name || "") !== "")) {
                hasActiveSpecial = true;
                break;
            }
        }
        root.specialActive = hasActiveSpecial;
    }

    Timer {
        id: specialDebounce
        interval: 25
        onTriggered: root.syncSpecialState()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "activespecial" || n === "activespecialv2" || n === "focusedmon" || n === "focusedmonv2" || n === "monitoradded" || n === "monitorremoved") {
                Hyprland.refreshMonitors();
                specialDebounce.restart();
            }
        }
    }

    Component.onCompleted: {
        Hyprland.refreshMonitors();
        syncSpecialState();
    }

    function shouldShow(screen) {
        if (barMode === "all")
            return true;
        if (barMode === "primary") {
            if (screen.isPrimary)
                return true;
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].x === 0 && screens[i].y === 0)
                    return screen === screens[i];
            }
            return screen === screens[0];
        }
        return screen.name === barMode;
    }

    readonly property var activeScreens: {
        const out = [];
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (shouldShow(screens[i]))
                out.push(screens[i]);
        }
        return out;
    }

    readonly property string barPosition: AppSettings.barPosition
    readonly property bool vertical: barPosition === "left" || barPosition === "right"
    readonly property bool atBottom: barPosition === "bottom"
    readonly property bool atRight: barPosition === "right"

    readonly property int barMargin: AppSettings.edgeToEdge ? 0 : 8
    readonly property int popupShadowMargin: 14

    function popupMainAxis(win, barWin) {
        if (!win)
            return 0;
        if (root.vertical) {
            return root.atRight ? -win.implicitWidth - 6 + root.popupShadowMargin : barWin.width + 6 - root.popupShadowMargin;
        }
        return root.atBottom ? -win.implicitHeight - 6 + root.popupShadowMargin : barWin.height + 6 - root.popupShadowMargin;
    }

    Variants {
        model: root.activeScreens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            visible: true
            exclusiveZone: 48 + root.barMargin

            anchors {
                top: root.vertical ? true : !root.atBottom
                bottom: root.vertical ? true : root.atBottom
                left: root.vertical ? !root.atRight : true
                right: root.vertical ? root.atRight : true
            }
            margins.top: root.vertical ? root.barMargin : (root.atBottom ? 0 : root.barMargin)
            margins.bottom: root.vertical ? root.barMargin : (root.atBottom ? root.barMargin : 0)
            margins.left: root.vertical ? (root.atRight ? 0 : root.barMargin) : root.barMargin
            margins.right: root.vertical ? (root.atRight ? root.barMargin : 0) : root.barMargin
            implicitWidth: 48
            implicitHeight: 48
            color: "transparent"
            WlrLayershell.layer: root.specialActive ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.keyboardFocus: (barWindow.audioOpen || barWindow.networkOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            property bool profileOpen: false
            property bool powerOpen: false
            property bool audioOpen: false
            property bool networkOpen: false
            property string networkInitialTab: "wifi"
            property bool centerOpen: false
            property bool notifOpen: false

            onProfileOpenChanged: {
                if (!profileOpen)
                    profileLinger.restart();
                else
                    profileLinger.stop();
                if (profileLoader.item)
                    profileLoader.item.open = profileOpen;
            }
            onPowerOpenChanged: {
                if (!powerOpen)
                    powerLinger.restart();
                else
                    powerLinger.stop();
                if (powerLoader.item)
                    powerLoader.item.open = powerOpen;
            }
            onAudioOpenChanged: {
                if (!audioOpen)
                    audioLinger.restart();
                else
                    audioLinger.stop();
                if (audioLoader.item)
                    audioLoader.item.open = audioOpen;
            }
            onNetworkOpenChanged: {
                if (!networkOpen)
                    networkLinger.restart();
                else
                    networkLinger.stop();
                if (networkLoader.item)
                    networkLoader.item.open = networkOpen;
            }
            onCenterOpenChanged: {
                if (!centerOpen)
                    centerLinger.restart();
                else
                    centerLinger.stop();
                if (centerPopupLoader.item)
                    centerPopupLoader.item.open = centerOpen;
            }
            onNotifOpenChanged: {
                if (!notifOpen) {
                    notifLinger.restart();
                } else {
                    notifLinger.stop();
                    NotificationService.markAllRead();
                }
                if (notifLoader.item)
                    notifLoader.item.open = notifOpen;
            }

            Timer {
                id: profileLinger
                interval: 220
            }
            Timer {
                id: powerLinger
                interval: 220
            }
            Timer {
                id: audioLinger
                interval: 230
            }
            Timer {
                id: networkLinger
                interval: 230
            }
            Timer {
                id: centerLinger
                interval: 220
            }
            Timer {
                id: notifLinger
                interval: 220
            }

            function closeOtherPopups(exceptName) {
                if (exceptName !== "profile")
                    barWindow.profileOpen = false;
                if (exceptName !== "power")
                    barWindow.powerOpen = false;
                if (exceptName !== "audio")
                    barWindow.audioOpen = false;
                if (exceptName !== "network")
                    barWindow.networkOpen = false;
                if (exceptName !== "notif")
                    barWindow.notifOpen = false;
                if (exceptName !== "center")
                    barWindow.centerOpen = false;
            }

            Rectangle {
                id: backdrop
                anchors.fill: parent
                radius: AppSettings.edgeToEdge ? 0 : 14
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.75)
                border.color: AppSettings.edgeToEdge ? "transparent" : Qt.rgba(1, 1, 1, 0.1)
                border.width: AppSettings.edgeToEdge ? 0 : 1
                antialiasing: !AppSettings.edgeToEdge

                Item {
                    id: content
                    anchors.fill: parent
                    anchors.leftMargin: root.vertical ? 0 : 14
                    anchors.rightMargin: root.vertical ? 0 : 14
                    anchors.topMargin: root.vertical ? 14 : 0
                    anchors.bottomMargin: root.vertical ? 14 : 0

                    GridLayout {
                        id: startGroup
                        x: root.vertical ? (content.width - width) / 2 : 0
                        y: root.vertical ? 0 : (content.height - height) / 2
                        rows: root.vertical ? -1 : 1
                        columns: root.vertical ? 1 : -1
                        rowSpacing: 8
                        columnSpacing: 8

                        Rectangle {
                            id: archButtonContainer
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 8
                            color: archHover.hovered || barWindow.profileOpen ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            HoverHandler {
                                id: archHover
                            }

                            Item {
                                anchors.centerIn: parent
                                width: 20
                                height: 20

                                Image {
                                    id: archLogoImg
                                    anchors.fill: parent
                                    source: "../../assets/logo.svg"
                                    sourceSize: Qt.size(64 * Screen.devicePixelRatio, 64 * Screen.devicePixelRatio)
                                    smooth: true
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.fill: archLogoImg
                                    source: archLogoImg
                                    colorization: 1.0
                                    colorizationColor: archHover.hovered || barWindow.profileOpen ? Colors.surfaceText : Colors.primary
                                    Behavior on colorizationColor {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    const willOpen = !barWindow.profileOpen;
                                    barWindow.closeOtherPopups("profile");
                                    barWindow.profileOpen = willOpen;
                                }
                            }
                        }

                        Separator {
                            barVertical: root.vertical
                        }

                        Workspaces {
                            vertical: root.vertical
                        }
                    }

                    Rectangle {
                        id: centerPill
                        x: (content.width - width) / 2
                        y: (content.height - height) / 2 + (root.vertical ? 4 : 0)
                        implicitWidth: root.vertical ? 32 : (centerLayout.implicitWidth + 24)
                        implicitHeight: root.vertical ? (centerLayout.implicitHeight + 24) : 32
                        radius: 8
                        color: centerHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        HoverHandler {
                            id: centerHover
                            onHoveredChanged: {
                                if (hovered) {
                                    popupHoverDelay.stop();
                                    barWindow.closeOtherPopups("center");
                                    barWindow.centerOpen = true;
                                } else {
                                    popupHoverDelay.start();
                                }
                            }
                        }

                        GridLayout {
                            id: centerLayout
                            anchors.centerIn: parent
                            rows: root.vertical ? -1 : 1
                            columns: root.vertical ? 1 : -1
                            rowSpacing: 10
                            columnSpacing: 10

                            Player {
                                id: barPlayer
                                visible: AppSettings.barShowPlayer
                                vertical: root.vertical
                                rightSide: root.atRight
                                Layout.row: root.vertical ? (root.atRight ? 2 : 0) : 0
                                Layout.column: root.vertical ? 0 : 2
                            }

                            Separator {
                                id: centerSep
                                barVertical: root.vertical
                                visible: barPlayer.active && barPlayer.visible
                                Layout.row: root.vertical ? 1 : 0
                                Layout.column: root.vertical ? 0 : 1
                            }

                            Clock {
                                id: mainClock
                                vertical: root.vertical
                                rightSide: root.atRight
                                showSeconds: barWindow.centerOpen
                                Layout.row: root.vertical ? (root.atRight ? 0 : 2) : 0
                                Layout.column: root.vertical ? 0 : 0
                            }
                        }
                    }

                    GridLayout {
                        id: endGroup
                        x: root.vertical ? (content.width - width) / 2 : (content.width - width)
                        y: root.vertical ? (content.height - height) : (content.height - height) / 2
                        rows: root.vertical ? -1 : 1
                        columns: root.vertical ? 1 : -1
                        rowSpacing: 6
                        columnSpacing: 6

                        Tray {
                            anchorWindow: barWindow
                            vertical: root.vertical
                            visible: AppSettings.barShowTray
                        }

                        Separator {
                            barVertical: root.vertical
                            Layout.leftMargin: root.vertical ? 0 : 4
                            Layout.rightMargin: root.vertical ? 0 : 4
                            Layout.topMargin: root.vertical ? 4 : 0
                            Layout.bottomMargin: root.vertical ? 4 : 0
                        }

                        AudioButton {
                            vertical: root.vertical
                            active: barWindow.audioOpen
                            onClicked: {
                                const willOpen = !barWindow.audioOpen;
                                barWindow.closeOtherPopups("audio");
                                barWindow.audioOpen = willOpen;
                            }
                        }

                        NetworkButton {
                            vertical: root.vertical
                            active: barWindow.networkOpen
                            onClicked: {
                                const willOpen = !barWindow.networkOpen;
                                if (willOpen)
                                    barWindow.networkInitialTab = "wifi";
                                barWindow.closeOtherPopups("network");
                                barWindow.networkOpen = willOpen;
                            }
                            onBluetoothRequested: {
                                if (barWindow.networkOpen && barWindow.networkInitialTab === "bluetooth") {
                                    barWindow.networkOpen = false;
                                } else {
                                    barWindow.closeOtherPopups("network");
                                    barWindow.networkInitialTab = "bluetooth";
                                    barWindow.networkOpen = true;
                                }
                            }
                        }

                        Notifications {
                            onToggleCenter: {
                                const willOpen = !barWindow.notifOpen;
                                barWindow.closeOtherPopups("notif");
                                barWindow.notifOpen = willOpen;
                            }
                        }

                        SettingsButton {
                            id: settingsBtn
                            active: ShellState.settingsWindowOpen
                            onClicked: {
                                barWindow.closeOtherPopups("");
                                ShellState.settingsWindowOpen = !ShellState.settingsWindowOpen;
                            }
                        }

                        PowerButton {
                            id: powerBtn
                            onClicked: {
                                const willOpen = !barWindow.powerOpen;
                                barWindow.closeOtherPopups("power");
                                barWindow.powerOpen = willOpen;
                            }
                        }
                    }
                }
            }

            LazyLoader {
                id: profileLoader
                active: barWindow.profileOpen || profileLinger.running
                ProfilePopup {
                    open: barWindow.profileOpen
                    onOpenChanged: if (open !== barWindow.profileOpen)
                        barWindow.profileOpen = open
                    anchor.window: barWindow
                    anchor.rect.x: root.vertical ? root.popupMainAxis(this, barWindow) : (12 - shadowMargin)
                    anchor.rect.y: root.vertical ? (12 - shadowMargin) : root.popupMainAxis(this, barWindow)
                }
            }

            LazyLoader {
                id: powerLoader
                active: barWindow.powerOpen || powerLinger.running
                PowerMenu {
                    open: barWindow.powerOpen
                    onOpenChanged: if (open !== barWindow.powerOpen)
                        barWindow.powerOpen = open
                    anchor.window: barWindow
                    anchor.rect.x: root.vertical ? root.popupMainAxis(this, barWindow) : (barWindow.width - implicitWidth - 12)
                    anchor.rect.y: root.vertical ? (barWindow.height - implicitHeight - 12) : root.popupMainAxis(this, barWindow)
                }
            }

            LazyLoader {
                id: audioLoader
                active: barWindow.audioOpen || audioLinger.running
                AudioPopup {
                    open: barWindow.audioOpen
                    onOpenChanged: if (open !== barWindow.audioOpen)
                        barWindow.audioOpen = open
                    anchor.window: barWindow
                    anchor.rect.x: root.vertical ? root.popupMainAxis(this, barWindow) : (barWindow.width - implicitWidth - 12)
                    anchor.rect.y: root.vertical ? (barWindow.height - implicitHeight - 12) : root.popupMainAxis(this, barWindow)
                }
            }

            LazyLoader {
                id: networkLoader
                active: barWindow.networkOpen || networkLinger.running
                NetworkPopup {
                    open: barWindow.networkOpen
                    activeTab: barWindow.networkInitialTab
                    onActiveTabChanged: if (activeTab !== barWindow.networkInitialTab)
                        barWindow.networkInitialTab = activeTab
                    onOpenChanged: if (open !== barWindow.networkOpen)
                        barWindow.networkOpen = open
                    anchor.window: barWindow
                    anchor.rect.x: root.vertical ? root.popupMainAxis(this, barWindow) : (barWindow.width - implicitWidth - 12)
                    anchor.rect.y: root.vertical ? (barWindow.height - implicitHeight - 12) : root.popupMainAxis(this, barWindow)
                }
            }

            LazyLoader {
                id: centerPopupLoader
                active: barWindow.centerOpen || centerLinger.running
                CenterPopup {
                    open: barWindow.centerOpen
                    onOpenChanged: if (open !== barWindow.centerOpen)
                        barWindow.centerOpen = open
                    onIsHoveredChanged: {
                        if (isHovered) {
                            popupHoverDelay.stop();
                            barWindow.closeOtherPopups("center");
                            barWindow.centerOpen = true;
                        } else {
                            popupHoverDelay.start();
                        }
                    }
                    anchor.window: barWindow
                    anchor.rect.x: root.vertical ? root.popupMainAxis(this, barWindow) : (barWindow.width / 2 - implicitWidth / 2)
                    anchor.rect.y: root.vertical ? (barWindow.height / 2 - implicitHeight / 2) : root.popupMainAxis(this, barWindow)
                    timeText: mainClock.timeSecStr
                }
            }

            LazyLoader {
                id: notifLoader
                active: barWindow.notifOpen || notifLinger.running
                NotificationCenter {
                    open: barWindow.notifOpen
                    onOpenChanged: if (open !== barWindow.notifOpen)
                        barWindow.notifOpen = open
                    anchor.window: barWindow
                    anchor.rect.x: root.vertical ? root.popupMainAxis(this, barWindow) : (barWindow.width - implicitWidth - 12)
                    anchor.rect.y: root.vertical ? (barWindow.height - implicitHeight - 12) : root.popupMainAxis(this, barWindow)
                }
            }

            Timer {
                id: profileHoverDelay
                interval: 400
                running: barWindow.profileOpen && !archHover.hovered && !(profileLoader.item && (profileLoader.item.isHovered || profileLoader.item.keepOpen))
                onTriggered: barWindow.profileOpen = false
            }

            Timer {
                id: popupHoverDelay
                interval: 200
                onTriggered: {
                    if (!centerHover.hovered && !(centerPopupLoader.item && centerPopupLoader.item.isHovered)) {
                        barWindow.centerOpen = false;
                    }
                }
            }
        }
    }
}
