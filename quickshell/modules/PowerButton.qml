// PowerButton.qml

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    radius: 8
    color: hover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    signal clicked()
    HoverHandler { id: hover }
    Text {
        anchors.centerIn: parent
        text: "\u23FB"
        color: hover.hovered ? Colors.primary : Qt.rgba(1, 1, 1, 0.75)
        font.pixelSize: 17
    }
    TapHandler {
        onTapped: root.clicked()
    }
}