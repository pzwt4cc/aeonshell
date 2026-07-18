// modules/Tray.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtCore

GridLayout {
    id: trayRoot

    property bool vertical: false
    property bool expanded: false
    property var anchorWindow

    rows: trayRoot.vertical ? -1 : 1
    columns: trayRoot.vertical ? 1 : -1
    rowSpacing: 6
    columnSpacing: 6

    Settings {
        id: traySettings
        category: "Tray"
        property var pinnedIds: ["telegram", "org.telegram.desktop"]
    }

    function isPinned(itemId) {
        return traySettings.pinnedIds.indexOf(itemId) !== -1;
    }

    function pinItem(itemId) {
        if (!isPinned(itemId)) {
            let arr = traySettings.pinnedIds.slice();
            arr.push(itemId);
            traySettings.pinnedIds = arr;
        }
    }

    function unpinItem(itemId) {
        let arr = traySettings.pinnedIds.slice();
        let index = arr.indexOf(itemId);
        if (index !== -1) {
            arr.splice(index, 1);
            traySettings.pinnedIds = arr;
        }
    }

    function showContextMenu(item, delegateItem, eventPoint) {
        if (!item || !item.hasMenu) return;
        if (!trayRoot.anchorWindow) {
            console.warn("Tray: anchorWindow not set, cannot show context menu");
            return;
        }
        let pos = delegateItem.mapToItem(trayRoot.anchorWindow.contentItem,
                                          eventPoint.position.x,
                                          eventPoint.position.y);
        item.display(trayRoot.anchorWindow, pos.x, pos.y);
    }

    component TrayIcon: Rectangle {
        id: iconDelegate
        required property var modelData
        property bool isPinnedSlot: false

        visible: isPinnedSlot ? isPinned(modelData.id) : !isPinned(modelData.id)
        Layout.preferredWidth: visible ? 28 : 0
        Layout.preferredHeight: visible ? 28 : 0
        radius: 6
        color: iconHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        opacity: dragHandler.active ? 0.4 : 1.0
        scale: dragHandler.active ? 0.85 : 1.0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        Behavior on scale { NumberAnimation { duration: 100 } }

        IconImage {
            anchors.centerIn: parent
            width: 18
            height: 18
            source: modelData.icon
        }

        HoverHandler { id: iconHover }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                if (modelData.activate) modelData.activate();
            }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (eventPoint) => trayRoot.showContextMenu(modelData, iconDelegate, eventPoint)
        }

        TapHandler {
            acceptedButtons: Qt.MiddleButton
            onTapped: {
                if (modelData.secondaryActivate) modelData.secondaryActivate();
            }
        }

        DragHandler {
            id: dragHandler
            grabPermissions: PointerHandler.CanTakeOverFromItems
            target: null

            onActiveChanged: {
                if (active) return;
                if (iconDelegate.isPinnedSlot) {
                    const overshoot = trayRoot.vertical
                        ? dragHandler.centroid.position.y > pinnedLayout.height + 40
                        : dragHandler.centroid.position.x > pinnedLayout.width + 40;
                    if (overshoot) unpinItem(modelData.id);
                } else {
                    const overshoot = trayRoot.vertical
                        ? dragHandler.centroid.position.y < 0
                        : dragHandler.centroid.position.x < 0;
                    if (overshoot) pinItem(modelData.id);
                }
            }
        }
    }

    GridLayout {
        id: pinnedLayout
        Layout.alignment: trayRoot.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        rows: trayRoot.vertical ? -1 : 1
        columns: trayRoot.vertical ? 1 : -1
        rowSpacing: 6
        columnSpacing: 6

        Repeater {
            model: SystemTray.items
            delegate: TrayIcon { isPinnedSlot: true }
        }
    }

    Item {
        id: hiddenContainer
        Layout.alignment: trayRoot.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        Layout.preferredWidth: trayRoot.vertical ? 32 : (trayRoot.expanded ? hiddenLayout.implicitWidth : 0)
        Layout.preferredHeight: trayRoot.vertical ? (trayRoot.expanded ? hiddenLayout.implicitHeight : 0) : 32
        clip: true

        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        GridLayout {
            id: hiddenLayout
            anchors.centerIn: parent
            rows: trayRoot.vertical ? -1 : 1
            columns: trayRoot.vertical ? 1 : -1
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: SystemTray.items
                delegate: TrayIcon { isPinnedSlot: false }
            }
        }
    }

    Rectangle {
        id: arrowButton
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        Layout.alignment: trayRoot.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        radius: 6
        color: arrowHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "󰅂"
            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
            font.pixelSize: 14

            rotation: (trayRoot.vertical ? 90 : 0) + (trayRoot.expanded ? 180 : 0)
            Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        }

        HoverHandler { id: arrowHover }
        TapHandler {
            onTapped: trayRoot.expanded = !trayRoot.expanded
        }
    }
}