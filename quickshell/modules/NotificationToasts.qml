// NotificationToasts.qml

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
            for (const s of Quickshell.screens) {
                if (s.name === mon.name) return s;
            }
        }
        return Quickshell.screens[0];
    }
    screen: toastWindow.activeScreen

    anchors { top: true; right: true }
    margins.top: 12
    margins.right: 12

    implicitWidth: 400
    implicitHeight: toastColumn.implicitHeight > 0 ? toastColumn.implicitHeight : 1
    
    visible: true
    exclusiveZone: 0
    color: "transparent"

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