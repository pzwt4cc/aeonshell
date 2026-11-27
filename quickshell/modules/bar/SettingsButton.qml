// SettingsButton.qml

import "../"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    radius: 8
    color: root.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2) : (btnMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent")
    border.color: root.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : "transparent"
    border.width: 1
    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    property bool active: false

    signal clicked

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: root.active ? Colors.primary : (btnMa.containsMouse ? Colors.surfaceText : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.78))
        font.pixelSize: 15
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
