// Audio.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

Rectangle {
    id: root
    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    radius: 8
    color: hover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    HoverHandler { id: hover }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.muted ? "󰖁" : "󰕾"
        color: root.muted ? Qt.rgba(1, 1, 1, 0.45) : "#ffffff"
        font.pixelSize: 14
    }

    TapHandler {
        onTapped: pavuProc.running = true
    }
    Process {
        id: pavuProc
        command: ["pavucontrol"]
    }
}