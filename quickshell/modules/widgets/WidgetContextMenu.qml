import QtQuick
import "../"

Item {
    id: root
    property var model: []
    property bool menuVisible: false
    visible: menuVisible
    width: 160
    height: model.length * 28 + 8

    function openAt(px, py) { x = px; y = py; menuVisible = true }
    function close() { menuVisible = false }

    Rectangle {
        anchors.fill: parent
        color: Colors.surface
        radius: 6
    }

    Column {
        anchors { fill: parent; margins: 4 }
        spacing: 0
        Repeater {
            model: root.model
            delegate: Rectangle {
                width: 152; height: 28
                color: hoverArea.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                Text {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: modelData.label
                    color: Colors.surfaceText
                    font.pixelSize: 12
                }
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { modelData.action(); root.close() }
                }
            }
        }
    }

    // клик снаружи меню — закрыть (вешать на родительский MouseArea уровнем выше)
}