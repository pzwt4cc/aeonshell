// WindowContextMenu.qml
//
// Small right-click menu for dock/taskbar entries: pin/unpin and close.
// Built the same way
// as CenterPopup.qml (PopupWindow + faux shadow + scale/opacity intro).
//
// Auto-close behavior: since this opens on right-click (not hover, like
// ProfilePopup), it doesn't start its close timer until the pointer has
// actually entered the menu at least once — otherwise it'd vanish before
// you get the mouse there. See dockMenuHoverDelay in Dock.qml.

import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup

    property bool open: false
    property string targetClass: ""
    property bool targetPinned: false
    property bool targetHasWindows: false

    readonly property bool isHovered: hover.hovered
    property bool hasBeenHovered: false
    onIsHoveredChanged: if (isHovered) hasBeenHovered = true

    signal pinToggleRequested(string cls)
    signal closeRequested(string cls)

    readonly property int itemHeight: 34
    readonly property int menuWidth: 170
    readonly property int shadowMargin: 12
    readonly property int itemCount: targetHasWindows ? 2 : 1

    implicitWidth: menuWidth + shadowMargin * 2
    implicitHeight: itemCount * itemHeight + 8 + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running

    Timer { id: hideTimer; interval: 150 }
    onOpenChanged: {
        hasBeenHovered = false;
        if (!open) hideTimer.start();
        else hideTimer.stop();
    }

    Rectangle {
        anchors.fill: menuBg
        anchors.margins: -4
        radius: menuBg.radius + 4
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: menuBg.opacity * 0.5
        scale: menuBg.scale
        transformOrigin: menuBg.transformOrigin
        z: menuBg.z - 1
    }

    Rectangle {
        id: menuBg
        anchors.fill: parent
        anchors.margins: popup.shadowMargin
        radius: 14
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.22)
        border.width: 1
        clip: true

        transformOrigin: Item.Top
        scale: popup.open ? 1.0 : 0.85
        opacity: popup.open ? 1.0 : 0.0

        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

        HoverHandler { id: hover }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: popup.itemHeight
                radius: 8
                color: pinHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    text: popup.targetPinned ? "Открепить" : "Закрепить"
                    font.pixelSize: 13
                    color: Colors.surfaceText
                }

                HoverHandler { id: pinHover }
                TapHandler {
                    onTapped: {
                        popup.pinToggleRequested(popup.targetClass);
                        popup.open = false;
                    }
                }
            }

            Rectangle {
                visible: popup.targetHasWindows
                Layout.fillWidth: true
                Layout.preferredHeight: popup.itemHeight
                radius: 8
                color: closeHover.hovered ? Qt.rgba(1, 0.35, 0.35, 0.15) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    text: "Закрыть"
                    font.pixelSize: 13
                    color: "#ff6b6b"
                }

                HoverHandler { id: closeHover }
                TapHandler {
                    onTapped: {
                        popup.closeRequested(popup.targetClass);
                        popup.open = false;
                    }
                }
            }
        }
    }
}
