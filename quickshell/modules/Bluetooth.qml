// Bluetooth.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root
    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    radius: 8
    color: hover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    property bool powered: false

    HoverHandler { id: hover }

    Text {
        id: label
        anchors.centerIn: parent
        text: "󰂯"
        color: root.powered ? "#ffffff" : Qt.rgba(1, 1, 1, 0.35)
        font.pixelSize: 14
    }

    Process {
        id: proc
        command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: root.powered = this.text.trim() === "on"
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    TapHandler {
        onTapped: managerProc.running = true
    }
    Process {
        id: managerProc
        command: ["blueman-manager"]
    }
}