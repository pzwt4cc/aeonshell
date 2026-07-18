// SettingsButton.qml

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    radius: 8
    color: (hover.hovered || root.active) ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    property bool active: false

    signal clicked()

    HoverHandler { id: hover }

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: (hover.hovered || root.active) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
        font.pixelSize: 15
    }

    TapHandler {
        onTapped: root.clicked()
    }
}