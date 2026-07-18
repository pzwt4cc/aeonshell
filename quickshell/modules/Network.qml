// Network.qml

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

    property string icon: "󰌺"

    HoverHandler { id: hover }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon
        color: "#ffffff"
        font.pixelSize: 14
    }

    Process {
        id: proc
        command: ["bash", "-c", "nmcli -t -f TYPE,STATE connection show --active 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                if (out.indexOf("ethernet") !== -1) root.icon = "󰌗";
                else if (out.indexOf("wireless") !== -1) root.icon = "󰖩";
                else root.icon = "󰌺";
            }
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
        onTapped: editorProc.running = true
    }
    Process {
        id: editorProc
        command: ["nm-connection-editor"]
    }
}