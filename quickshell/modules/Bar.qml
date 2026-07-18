// Bar.qml

import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

Scope {
    id: root

    readonly property string barMode: "primary"

    property bool specialActive: false

    Process {
        id: specialWatcher
        running: true
        command: [
            "bash", "-c",
            "get_state() { hyprctl monitors -j 2>/dev/null | tr -d '\\n'; echo; }; " +
            "get_state; " +
            "stdbuf -oL socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null | " +
            "stdbuf -oL grep --line-buffered -E 'activespecial>>' | " +
            "while read -r line; do get_state; done"
        ]
        stdout: SplitParser {
            onRead: text => {
                const clean = text.trim();
                if (!clean) return;
                try {
                    const monitorsArr = JSON.parse(clean);
                    let hasActiveSpecial = false;
                    for (let i = 0; i < monitorsArr.length; i++) {
                        if (monitorsArr[i].specialWorkspace && monitorsArr[i].specialWorkspace.id !== 0) {
                            hasActiveSpecial = true;
                            break;
                        }
                    }
                    root.specialActive = hasActiveSpecial;
                } catch (err) { }
            }
        }
    }

    function shouldShow(screen) {
        if (barMode === "all") return true;
        if (barMode === "primary") {
            if (screen.isPrimary) return true;
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].x === 0 && screens[i].y === 0) return screen === screens[i];
            }
            return screen === screens[0];
        }
        return screen.name === barMode;
    }

    readonly property string barPosition: AppSettings.barPosition
    readonly property bool vertical: barPosition === "left" || barPosition === "right"
    readonly property bool atBottom: barPosition === "bottom"
    readonly property bool atRight: barPosition === "right"

    readonly property int barMargin: AppSettings.edgeToEdge ? 0 : 8

    readonly property int popupShadowMargin: 14

    function popupMainAxis(win, barWin) {
        if (root.vertical) {
            return root.atRight
                ? -win.implicitWidth - 6 + root.popupShadowMargin
                : barWin.width + 6 - root.popupShadowMargin;
        }
        return root.atBottom
            ? -win.implicitHeight - 6 + root.popupShadowMargin
            : barWin.height + 6 - root.popupShadowMargin;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            visible: root.shouldShow(modelData)
            exclusiveZone: visible ? (48 + root.barMargin) : 0

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
            WlrLayershell.keyboardFocus: (controlCenter.open && controlCenter.pendingSsid !== "")
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            function closeOtherPopups(except) {
                if (profilePopup !== except) profilePopup.open = false
                if (powerMenu !== except) powerMenu.open = false
                if (controlCenter !== except) controlCenter.open = false
                if (notificationCenter !== except) notificationCenter.open = false
                if (centerPopup !== except) centerPopup.open = false
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
                            color: archHover.hovered || profilePopup.open ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: archHover }

                            Item {
                                anchors.centerIn: parent
                                width: 20
                                height: 20

                                Image {
                                    id: archLogoImg
                                    anchors.fill: parent
                                    source: "../assets/logo.svg"
                                    sourceSize: Qt.size(64 * Screen.devicePixelRatio, 64 * Screen.devicePixelRatio)
                                    smooth: true
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: archLogoImg
                                    source: archLogoImg
                                    color: archHover.hovered || profilePopup.open ? Colors.surfaceText : Colors.primary
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    const willOpen = !profilePopup.open
                                    barWindow.closeOtherPopups(profilePopup)
                                    profilePopup.open = willOpen
                                }
                            }
                        }

                        Separator { barVertical: root.vertical }

                        Workspaces { vertical: root.vertical }
                    }

                    Rectangle {
                        id: centerPill
                        x: (content.width - width) / 2
                        y: (content.height - height) / 2 + (root.vertical ? 4 : 0)
                        implicitWidth: root.vertical ? 32 : (centerLayout.implicitWidth + 24)
                        implicitHeight: root.vertical ? (centerLayout.implicitHeight + 24) : 32
                        radius: 8
                        color: centerHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        HoverHandler { id: centerHover }

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

                        Tray { anchorWindow: barWindow; vertical: root.vertical; visible: AppSettings.barShowTray }

                        Separator {
                            barVertical: root.vertical
                            Layout.leftMargin: root.vertical ? 0 : 4
                            Layout.rightMargin: root.vertical ? 0 : 4
                            Layout.topMargin: root.vertical ? 4 : 0
                            Layout.bottomMargin: root.vertical ? 4 : 0
                        }
                        Notifications {
                            onToggleCenter: {
                                const willOpen = !notificationCenter.open
                                barWindow.closeOtherPopups(notificationCenter)
                                notificationCenter.open = willOpen
                            }
                        }
                        SettingsButton {
                            id: settingsBtn
                            active: controlCenter.open
                            onClicked: {
                                const willOpen = !controlCenter.open
                                barWindow.closeOtherPopups(controlCenter)
                                controlCenter.open = willOpen
                            }
                        }
                        PowerButton {
                            id: powerBtn
                            onClicked: {
                                const willOpen = !powerMenu.open
                                barWindow.closeOtherPopups(powerMenu)
                                powerMenu.open = willOpen
                            }
                        }
                    }
                }
            }

            ProfilePopup {
                id: profilePopup
                anchor.window: barWindow
                anchor.rect.x: root.vertical
                    ? root.popupMainAxis(profilePopup, barWindow)
                    : (12 - profilePopup.shadowMargin)
                anchor.rect.y: root.vertical
                    ? (12 - profilePopup.shadowMargin)
                    : root.popupMainAxis(profilePopup, barWindow)
            }

            PowerMenu {
                id: powerMenu
                anchor.window: barWindow
                anchor.rect.x: root.vertical
                    ? root.popupMainAxis(powerMenu, barWindow)
                    : (barWindow.width - implicitWidth - 12)
                anchor.rect.y: root.vertical
                    ? (barWindow.height - implicitHeight - 12)
                    : root.popupMainAxis(powerMenu, barWindow)
            }

            ControlCenter {
                id: controlCenter
                anchor.window: barWindow
                anchor.rect.x: root.vertical
                    ? root.popupMainAxis(controlCenter, barWindow)
                    : (barWindow.width - implicitWidth - 12)
                anchor.rect.y: root.vertical
                    ? (barWindow.height - implicitHeight - 12)
                    : root.popupMainAxis(controlCenter, barWindow)
            }

            CenterPopup {
                id: centerPopup
                anchor.window: barWindow
                anchor.rect.x: root.vertical
                    ? root.popupMainAxis(centerPopup, barWindow)
                    : (barWindow.width / 2 - implicitWidth / 2)
                anchor.rect.y: root.vertical
                    ? (barWindow.height / 2 - implicitHeight / 2)
                    : root.popupMainAxis(centerPopup, barWindow)
                timeText: mainClock.timeSecStr
            }

            NotificationCenter {
                id: notificationCenter
                anchor.window: barWindow
                anchor.rect.x: root.vertical
                    ? root.popupMainAxis(notificationCenter, barWindow)
                    : (barWindow.width - implicitWidth - 12)
                anchor.rect.y: root.vertical
                    ? (barWindow.height - implicitHeight - 12)
                    : root.popupMainAxis(notificationCenter, barWindow)
            }

            Timer {
                id: profileHoverDelay
                interval: 400
                running: profilePopup.open && !archHover.hovered && !profilePopup.isHovered
                onTriggered: {
                    profilePopup.open = false;
                }
            }

            Timer {
                id: popupHoverDelay
                interval: 200
                onTriggered: {
                    if (!centerHover.hovered && !centerPopup.isHovered) {
                        centerPopup.open = false;
                    }
                }
            }

            Connections {
                target: centerHover
                function onHoveredChanged() {
                    if (centerHover.hovered) {
                        popupHoverDelay.stop();
                        barWindow.closeOtherPopups(centerPopup)
                        centerPopup.open = true;
                    } else {
                        popupHoverDelay.start();
                    }
                }
            }

            Connections {
                target: centerPopup
                function onIsHoveredChanged() {
                    if (centerPopup.isHovered) {
                        popupHoverDelay.stop();
                        barWindow.closeOtherPopups(centerPopup)
                        centerPopup.open = true;
                    } else {
                        popupHoverDelay.start();
                    }
                }
            }
        }
    }
}