// Separator.qml

import QtQuick
import QtQuick.Layouts

Rectangle {
    property bool barVertical: false

    Layout.preferredWidth: barVertical ? 16 : 1
    Layout.preferredHeight: barVertical ? 1 : 16
    Layout.alignment: barVertical ? Qt.AlignHCenter : Qt.AlignVCenter
    color: Qt.rgba(1, 1, 1, 0.15)
}