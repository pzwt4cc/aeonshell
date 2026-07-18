// Notifications.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
    id: root
    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    radius: 8
    color: hover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

    signal toggleCenter

    readonly property int count: NotificationService.active.length

    HoverHandler { id: hover }

    TapHandler {
        onTapped: root.toggleCenter()
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: "󰂚"
        color: root.count > 0 ? Colors.error : (hover.hovered ? Colors.primary : "#ffffff")
        font.pixelSize: 14
    }
}