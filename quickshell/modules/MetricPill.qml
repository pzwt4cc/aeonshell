// MetricPill.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property string command: ""
    property int intervalMs: 2000
    property string value: "..."

    Layout.preferredWidth: label.implicitWidth
    Layout.preferredHeight: label.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    Text {
        id: label
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        text: root.value
        color: "#ffffff"
        font.pixelSize: 13
        font.bold: true
    }

    Process {
        id: proc
        command: ["bash", "-c", root.command]
        stdout: StdioCollector {
            onStreamFinished: root.value = this.text.trim()
        }
    }

    Timer {
        interval: root.intervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}