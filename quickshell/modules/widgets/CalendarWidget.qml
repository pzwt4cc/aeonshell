import QtQuick
import "../"

Item {
    id: root
    implicitWidth: 240
    implicitHeight: 240
    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()

    function daysInMonth() { return new Date(year, month + 1, 0).getDate() }
    function firstDayOffset() { return (new Date(year, month, 1).getDay() + 6) % 7 } // пн=0

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "#141414"
        opacity: 0.55
        border.color: "#40ffffff"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6
        Text {
            text: today.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            color: "white"
            font.pixelSize: 16
            font.weight: Font.Medium
            style: Text.Outline
            styleColor: "black"
        }
        Grid {
            columns: 7
            spacing: 4
            Repeater {
                model: root.firstDayOffset()
                delegate: Item { width: 26; height: 26 }
            }
            Repeater {
                model: root.daysInMonth()
                delegate: Rectangle {
                    width: 26; height: 26
                    radius: 13
                    color: (index + 1) === today.getDate() ? Colors.accent : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        color: "white"
                        font.pixelSize: 11
                        style: Text.Outline
                        styleColor: "black"
                    }
                }
            }
        }
    }
}
