// PowerMenuAction.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root
    property string glyph: ""
    property var command: []

    signal activated()

    Layout.preferredWidth: 46
    Layout.preferredHeight: 46
    Layout.alignment: Qt.AlignVCenter


    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: hover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : "transparent"
        border.color: hover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3) : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: hover.hovered ? Colors.primary : Colors.surfaceText
        font.pixelSize: 20
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
        scale: hover.hovered ? 1.12 : 1.0
    }

    HoverHandler { id: hover }

    TapHandler {
        onTapped: {
            proc.running = true;
            root.activated();
        }
    }

    Process {
        id: proc
        command: root.command
    }
}