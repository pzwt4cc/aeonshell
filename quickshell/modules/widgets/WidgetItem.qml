import QtQuick
import "../"
import "."

Item {
    id: item
    required property var widgetData

    x: widgetData.x
    y: widgetData.y
    width: 160
    height: 70

    // Загрузка виджета по типу
    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: {
            if (widgetData.type === "clock") return clockComp
            if (widgetData.type === "calendar") return calComp
            return null
        }
    }

    Component {
        id: clockComp
        ClockWidget {}
    }

    Component {
        id: calComp
        CalendarWidget {}
    }

    // Зона перетаскивания и меню
    MouseArea {
        anchors.fill: parent
        enabled: !widgetData.locked
        drag.target: item
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onReleased: WidgetManager.commitPosition(widgetData.id, item.x, item.y)
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                menu.openAt(mouse.x, mouse.y)
            }
        }
    }

    WidgetContextMenu {
        id: menu
        model: [
            { label: widgetData.locked ? "Unpin" : "Pin", action: () => WidgetManager.toggleLock(widgetData.id) },
            { label: "Switch to Clock", action: () => WidgetManager.changeType(widgetData.id, "clock") },
            { label: "Switch to Calendar", action: () => WidgetManager.changeType(widgetData.id, "calendar") },
            { label: "Remove", action: () => WidgetManager.removeWidget(widgetData.id) }
        ]
    }
}