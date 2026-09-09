// Dock.qml

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets

Scope {
    id: root

    readonly property bool dockEnabled: AppSettings.barShowWindows

    property int changeEpoch: 0

    property var _origWorkspace: ({})

    readonly property int btnSize: 44
    readonly property int btnSpacing: 10
    readonly property int edgePadding: 8
    readonly property int dockMargin: 10

    readonly property string activeAddress: Hyprland.activeToplevel ? Hyprland.activeToplevel.address.toLowerCase() : ""

    function addrEq(a, b) {
        return !!a && !!b && a.toLowerCase() === b.toLowerCase();
    }

    function normAddr(a) {
        return a ? a.toLowerCase() : "";
    }

    function fullAddr(a) {
        if (!a) return a;
        return a.indexOf("0x") === 0 ? a : "0x" + a;
    }

    readonly property var groups: (root.changeEpoch, root.computeGroups())
    readonly property var pinnedGroups: root.groups.filter(g => g.pinned)
    readonly property var runningGroups: root.groups.filter(g => !g.pinned)

    function shouldShow(screen) {
        if (screen.isPrimary) return true;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].x === 0 && screens[i].y === 0) return screen === screens[i];
        }
        return screen === screens[0];
    }

    function isSpecial(win) {
        return !!(win.workspace && win.workspace.name && win.workspace.name.indexOf("special") === 0);
    }

    function computeGroups() {
        const list = Hyprland.toplevels.values;
        const map = {};
        const order = [];
        for (const w of list) {
            const cls = (w.lastIpcObject && w.lastIpcObject.class) || "unknown";
            if (!map[cls]) { map[cls] = []; order.push(cls); }
            map[cls].push(w);
        }
        root.dbg("computeGroups: " + list.length + " toplevels -> classes [" + order.join(", ") + "]");

        const pinned = AppSettings.pinnedList();
        const groups = [];
        for (const cls of pinned) {
            groups.push({ cls: cls, windows: map[cls] || [], pinned: true });
        }

        const runningOrder = order.filter(cls => pinned.indexOf(cls) === -1);
        runningOrder.sort((a, b) => {
            const addrA = (map[a][0] && map[a][0].address) || "";
            const addrB = (map[b][0] && map[b][0].address) || "";
            return addrA < addrB ? -1 : addrA > addrB ? 1 : 0;
        });
        for (const cls of runningOrder) {
            groups.push({ cls: cls, windows: map[cls], pinned: false });
        }
        return groups;
    }

    function findAppForClass(cls) {
        if (!cls) return null;
        return DesktopEntries.heuristicLookup(cls);
    }

    function activateGroup(group) {
        if (group.windows.length === 0) {
            const app = root.findAppForClass(group.cls);
            if (app) app.execute();
            return;
        }
        const focused = group.windows.find(w => w.activated || root.addrEq(w.address, root.activeAddress));
        if (focused) {
            root.minimize(focused);
            return;
        }
        const hidden = group.windows.find(w => root.isSpecial(w));
        root.bringToCurrentWorkspace(hidden || group.windows[0]);
    }

    function dbg(msg) { console.log("[Dock]", msg); }

    readonly property bool usingLua: Hyprland.usingLua

    function dispatch(legacy, lua) {
        const req = root.usingLua ? lua : legacy;
        root.dbg("usingLua=" + root.usingLua + " dispatch: " + req);
        Hyprland.dispatch(req);
    }

    function luaWinSel(addr) {
        return 'hl.get_windows({ address = "' + root.fullAddr(addr) + '" })[1]';
    }

    function focusAddress(addr) {
        root.dispatch(
            "focuswindow address:" + root.fullAddr(addr),
            'hl.dsp.focus({ window = ' + root.luaWinSel(addr) + ' })'
        );
    }

    function minimize(win) {
        root._origWorkspace[root.normAddr(win.address)] = win.workspace ? win.workspace.id : 0;
        root.dispatch(
            "movetoworkspacesilent special:minimized,address:" + root.fullAddr(win.address),
            'hl.dsp.window.move({ workspace = "special:minimized", window = ' + root.luaWinSel(win.address) + ', follow = false })'
        );
    }

    function bringToCurrentWorkspace(win) {
        const key = root.normAddr(win.address);
        const weMinimizedIt = root._origWorkspace[key] !== undefined;
        delete root._origWorkspace[key];

        const isOtherSpecial = !weMinimizedIt && root.isSpecial(win);
        if (isOtherSpecial) {
            const wsName = (win.workspace && win.workspace.name) || "";
            const name = wsName === "special" ? "" : wsName.replace("special:", "");
            root.dispatch(
                "togglespecialworkspace " + name,
                'hl.dsp.workspace.toggle_special("' + name + '")'
            );
            root.focusAddress(win.address);
            return;
        }

        const target = (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
            ? Hyprland.focusedMonitor.activeWorkspace.id
            : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1);
        root.dispatch(
            "movetoworkspacesilent " + target + ",address:" + root.fullAddr(win.address),
            'hl.dsp.window.move({ workspace = ' + target + ', window = ' + root.luaWinSel(win.address) + ', follow = false })'
        );
        root.focusAddress(win.address);
    }

    function closeGroup(group) {
        for (const w of group.windows) {
            if (w.wayland) w.wayland.close();
            else root.dispatch(
                "closewindow address:" + root.fullAddr(w.address),
                'hl.dsp.window.close({ window = ' + root.luaWinSel(w.address) + ' })'
            );
        }
    }

    function closeGroupByClass(cls) {
        const group = root.groups.find(g => g.cls === cls);
        if (group) root.closeGroup(group);
    }

    Component.onCompleted: {
        root.dbg("started, usingLua=" + Hyprland.usingLua);
        Hyprland.refreshToplevels();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            root.dbg("event: " + event.name);
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "activewindow":
            case "activewindowv2":
            case "movewindow":
            case "movewindowv2":
            case "windowtitlev2":
            case "workspace":
            case "workspacev2":
            case "focusedmon":
                root.changeEpoch++;
                root.dbg("changeEpoch -> " + root.changeEpoch + ", toplevels=" + Hyprland.toplevels.values.length);
                break;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWindow
            required property var modelData
            screen: modelData

            visible: root.dockEnabled && root.shouldShow(modelData) && root.groups.length > 0
            exclusiveZone: visible ? (dockBg.implicitHeight + root.dockMargin) : 0

            anchors { bottom: true }
            margins.bottom: root.dockMargin
            implicitWidth: dockBg.implicitWidth
            implicitHeight: dockBg.implicitHeight
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-dock"

            function closeMenu() { dockMenu.open = false }

            RectangularShadow {
                anchors.fill: dockBg
                anchors.margins: -6
                radius: dockBg.radius
                color: Qt.rgba(0, 0, 0, 0.4)
                blur: 22
                spread: 0
                offset: Qt.point(0, 5)
            }

            Rectangle {
                id: dockBg
                implicitWidth: dockRow.implicitWidth + root.edgePadding * 2
                implicitHeight: root.btnSize + root.edgePadding * 2
                radius: 18
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.78)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 1
                    radius: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                Row {
                    id: dockRow
                    anchors.centerIn: parent
                    spacing: root.btnSpacing

                    Repeater {
                        model: root.pinnedGroups
                        delegate: dockButtonComponent
                    }

                    Rectangle {
                        visible: root.pinnedGroups.length > 0 && root.runningGroups.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: root.btnSize * 0.6
                        color: Qt.rgba(1, 1, 1, 0.14)
                    }

                    Repeater {
                        model: root.runningGroups
                        delegate: dockButtonComponent
                    }
                }
            }

            Component {
                id: dockButtonComponent

                Rectangle {
                    id: btn
                    required property var modelData

                    width: root.btnSize
                    height: root.btnSize
                    radius: 11

                    readonly property bool isFocused: modelData.windows.some(w => w.activated || root.addrEq(w.address, root.activeAddress))
                    readonly property bool hasWindows: modelData.windows.length > 0
                    readonly property bool isMinimized: hasWindows && !isFocused &&
                        modelData.windows.every(w => root.isSpecial(w))
                    readonly property var app: root.findAppForClass(modelData.cls)

                    color: isFocused
                        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.22)
                        : (btnHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    opacity: hasWindows ? (isMinimized ? 0.55 : 1.0) : 0.4
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    scale: btnHover.hovered ? 1.16 : 1.0
                    y: btnHover.hovered ? -5 : 0
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                    Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

                    HoverHandler { id: btnHover }

                    IconImage {
                        visible: btn.app !== null
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: btn.app ? Quickshell.iconPath(btn.app.icon, true) : ""
                    }

                    Text {
                        visible: btn.app === null
                        anchors.centerIn: parent
                        text: modelData.cls ? modelData.cls.charAt(0).toUpperCase() : "?"
                        font.pixelSize: 18
                        font.bold: true
                        color: Colors.surfaceText
                    }

                    Rectangle {
                        visible: modelData.windows.length > 0
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: -6
                        width: 4
                        height: 4
                        radius: 2
                        color: btn.isFocused ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                    }

                    Rectangle {
                        visible: modelData.pinned && modelData.windows.length <= 1
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 3
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Colors.primary
                        opacity: 0.8
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: root.activateGroup(modelData)
                    }

                    TapHandler {
                        acceptedButtons: Qt.MiddleButton
                        onTapped: if (btn.hasWindows) root.closeGroup(modelData)
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            const pos = btn.mapToItem(dockWindow.contentItem, btn.width / 2, 0);
                            dockMenu.targetClass = modelData.cls;
                            dockMenu.targetPinned = modelData.pinned;
                            dockMenu.targetHasWindows = modelData.windows.length > 0;
                            dockMenu.anchor.rect.x = pos.x - dockMenu.implicitWidth / 2;
                            dockMenu.anchor.rect.y = pos.y - dockMenu.implicitHeight;
                            dockMenu.open = true;
                        }
                    }

                    Rectangle {
                        id: tip
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 6
                        color: Qt.rgba(0.05, 0.05, 0.05, 0.92)
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                        implicitWidth: tipText.implicitWidth + 16
                        implicitHeight: tipText.implicitHeight + 8
                        opacity: btnHover.hovered ? 1.0 : 0.0
                        visible: opacity > 0
                        scale: btnHover.hovered ? 1.0 : 0.92
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                        Text {
                            id: tipText
                            anchors.centerIn: parent
                            text: modelData.windows.length > 0
                                ? (modelData.windows.length === 1 ? modelData.windows[0].title : modelData.cls + " (" + modelData.windows.length + ")")
                                : modelData.cls
                            color: "white"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            WindowContextMenu {
                id: dockMenu
                anchor.window: dockWindow
                onPinToggleRequested: cls => AppSettings.togglePinned(cls)
                onCloseRequested: cls => root.closeGroupByClass(cls)
            }

            Timer {
                id: dockMenuHoverDelay
                interval: 400
                running: dockMenu.open && dockMenu.hasBeenHovered && !dockMenu.isHovered
                onTriggered: dockMenu.open = false
            }
        }
    }
}
