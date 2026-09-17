import QtQuick

Item {
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#1e1e2e"
        border.color: "#45475a"
        border.width: 1
    }

    Text {
        id: timeText
        anchors.centerIn: parent
        text: Qt.formatTime(new Date(), "hh:mm:ss")
        color: "#cdd6f4"
        font.pixelSize: 26
        font.bold: true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm:ss")
    }
}