// PowerMenu.qml

import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup

    property bool open: false
    readonly property bool isHovered: menuHover.hovered

    function toggle() { popup.open = !popup.open }

    readonly property int shadowMargin: 12

    implicitWidth: 330 + shadowMargin * 2
    implicitHeight: 78 + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running


    Timer {
        id: hideTimer
        interval: 150
    }

    property bool menuWasEntered: false

    Timer {
        id: closeDelayTimer
        interval: 450
        onTriggered: {
            popup.open = false
            menuWasEntered = false
        }
    }

    onOpenChanged: {
        if (!open) {
            hideTimer.start()
            menuWasEntered = false
            closeDelayTimer.stop()
        } else {
            hideTimer.stop()
        }
    }

    Rectangle {
        anchors.fill: menuBg
        anchors.margins: -5
        radius: menuBg.radius + 5
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: menuBg.opacity * 0.35
        scale: menuBg.scale
        transformOrigin: menuBg.transformOrigin
        z: menuBg.z - 1
    }

    Rectangle {
        id: menuBg
        anchors.fill: parent
        anchors.margins: popup.shadowMargin
        radius: 20
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.94)
        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
        border.width: 1

        transformOrigin: {
            if (AppSettings.barPosition === "bottom") return Item.BottomRight
            if (AppSettings.barPosition === "left") return Item.BottomLeft
            if (AppSettings.barPosition === "right") return Item.BottomRight
            return Item.TopRight
        }
        scale: popup.open ? 1.0 : 0.75
        opacity: popup.open ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        HoverHandler {
            id: menuHover
            onHoveredChanged: {
                if (menuHover.hovered) {
                    menuWasEntered = true
                    closeDelayTimer.stop()
                } else if (menuWasEntered) {
                    closeDelayTimer.start()
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            PowerMenuAction {
                glyph: "󰌾"
                command: ["hyprlock"]
                onActivated: popup.open = false
            }
            PowerMenuAction {
                glyph: "󰍃"
                command: ["hyprctl", "dispatch", "exit"]
                onActivated: popup.open = false
            }
            PowerMenuAction {
                glyph: "󰽥"
                command: ["systemctl", "suspend"]
                onActivated: popup.open = false
            }
            PowerMenuAction {
                glyph: "󰜉"
                command: ["systemctl", "reboot"]
                onActivated: popup.open = false
            }
            PowerMenuAction {
                glyph: "󰤂"
                command: ["systemctl", "poweroff"]
                onActivated: popup.open = false
            }
        }
    }
}