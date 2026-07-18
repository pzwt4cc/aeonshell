// Clock.qml

import QtQuick
import QtQuick.Layouts

GridLayout {
    id: root
    
    property bool vertical: false
    property bool rightSide: true
    property bool hovered: false
    property color accentColor: "#ffffff"
    property color defaultColor: "#ffffff"
    property string timeStr: ""
    property string dateStr: ""
    property string timeSecStr: ""

    readonly property int rotationAngle: root.rightSide ? 90 : -90

    Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter

    rows: root.vertical ? -1 : 1
    columns: root.vertical ? 1 : -1
    rowSpacing: 10
    columnSpacing: 10

    onVerticalChanged: root.update()

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
            Behavior on color { ColorAnimation { duration: 150 } }
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

    function update() {
        const now = new Date();
        root.timeStr = Qt.formatDateTime(now, "hh:mm");
        root.dateStr = Qt.formatDateTime(now, root.vertical ? "ddd, d MMM" : "dddd, MMM d");
        root.timeSecStr = Qt.formatDateTime(now, "hh:mm:ss");
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.update()
    }
}