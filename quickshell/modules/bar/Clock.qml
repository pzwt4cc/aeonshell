// Clock.qml

import "../"
import QtQuick
import QtQuick.Layouts
import Quickshell

GridLayout {
    id: root

    property bool vertical: false
    property bool rightSide: true
    property bool hovered: false
    property bool showSeconds: false
    property color defaultColor: "#ffffff"

    readonly property int rotationAngle: root.rightSide ? 90 : -90

    SystemClock {
        id: sysClock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property string timeStr: Qt.formatDateTime(sysClock.date, "hh:mm")
    readonly property string dateStr: Qt.formatDateTime(sysClock.date, root.vertical ? "ddd, d MMM" : "dddd, MMM d")
    readonly property string timeSecStr: root.showSeconds ? Qt.formatDateTime(sysClock.date, "hh:mm:ss") : ""

    Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter

    rows: root.vertical ? -1 : 1
    columns: root.vertical ? 1 : -1
    rowSpacing: 10
    columnSpacing: 10

    component RotatedLabel: Item {
        id: wrap
        property alias text: label.text
        property color textColor: "#ffffff"

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        implicitWidth: root.vertical ? label.implicitHeight : label.implicitWidth
        implicitHeight: root.vertical ? label.implicitWidth : label.implicitHeight

        Text {
            id: label
            anchors.centerIn: parent
            color: wrap.textColor
            font.pixelSize: 14
            font.bold: true
            rotation: root.vertical ? root.rotationAngle : 0
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }

    readonly property int timeRow: (root.vertical && !root.rightSide) ? 2 : 0
    readonly property int dateRow: (root.vertical && !root.rightSide) ? 0 : 2

    RotatedLabel {
        text: root.timeStr
        textColor: root.hovered ? "#ffb4ab" : root.defaultColor
        Layout.row: root.vertical ? root.timeRow : 0
        Layout.column: root.vertical ? 0 : 0
    }

    Separator {
        barVertical: root.vertical
        Layout.row: root.vertical ? 1 : 0
        Layout.column: root.vertical ? 0 : 1
    }

    RotatedLabel {
        text: root.dateStr
        textColor: root.hovered ? "#ffb4ab" : root.defaultColor
        Layout.row: root.vertical ? root.dateRow : 0
        Layout.column: root.vertical ? 0 : 2
    }
}
