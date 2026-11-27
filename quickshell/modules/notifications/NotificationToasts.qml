// NotificationToasts.qml

import "../"
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: toastWindow

    readonly property var activeScreen: {
        const mon = Hyprland.focusedMonitor;
        if (mon) {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i];
            }
        }
        return Quickshell.screens[0] || null;
    }
    screen: toastWindow.activeScreen

    anchors {
        top: true
        right: true
    }
    margins.top: 12
    margins.right: 12

    implicitWidth: 400
    implicitHeight: toastColumn.implicitHeight > 0 ? toastColumn.implicitHeight : 1

    visible: NotificationService.active.length > 0
    exclusiveZone: 0
    color: "transparent"

    mask: toastColumn.implicitHeight > 0 ? null : emptyMask
    Region {
        id: emptyMask
    }

    WlrLayershell.layer: WlrLayer.Overlay

    ColumnLayout {
        id: toastColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Repeater {
            model: NotificationService.active
            delegate: ToastCard {
                notif: modelData
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
            }
        }
    }
}
