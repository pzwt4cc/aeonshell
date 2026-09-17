import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: layer
    required property var modelData // screen из Variants
    screen: modelData

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // RMB on empty space — open add-widget menu. LMB — close it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                addMenu.x = mouse.x
                addMenu.y = mouse.y
                addMenu.visible = true
            } else {
                addMenu.visible = false
            }
        }
    }

    WidgetContextMenu {
        id: addMenu
        model: [
            { label: "Clock", action: () => WidgetManager.addWidget("clock", layer.screen.name, addMenu.x, addMenu.y) },
            { label: "Calendar", action: () => WidgetManager.addWidget("calendar", layer.screen.name, addMenu.x, addMenu.y) }
        ]
    }

    Repeater {
        model: WidgetManager.widgets.filter(w => w.screen === layer.screen.name)
        delegate: WidgetItem { widgetData: modelData }
    }
}