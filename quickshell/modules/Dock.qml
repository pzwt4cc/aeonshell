// Dock.qml
//
// macOS-style dock: a standalone floating panel anchored to the bottom
// of the screen, showing pinned apps + open windows grouped by class.
//
// This is intentionally a separate PanelWindow from Bar.qml (not a widget
// glued into the bar's layout) so it doesn't inherit the bar's position
// setting — the dock always sits at the bottom, like on macOS, no matter
// where AppSettings.barPosition puts the top bar.
//
// Window tracking + activate/minimize/restore logic is the same one that
// used to live in OpenWindows.qml — moved here since the windows list is
// no longer embedded in the bar itself. OpenWindows.qml is unused now and
// can be deleted once you're happy with this.
//
// Toggle: AppSettings.barShowWindows (same setting as before — enables/
// disables the dock). Rename later if "barShowWindows" stops making sense.

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import QtQuick.Effects

Scope {
    id: root

    readonly property bool dockEnabled: AppSettings.barShowWindows

    property var windows: []
    property string activeAddress: ""
    property var activeWorkspace: ({ id: 1, name: "1" })
    property var _origWorkspace: ({})

    readonly property int btnSize: 44
    readonly property int btnSpacing: 10
    readonly property int edgePadding: 8
    readonly property int dockMargin: 10

    readonly property var groups: root.computeGroups()
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

    function computeGroups() {
        const list = root.windows || [];
        const map = {};
        const order = [];
        for (const w of list) {
            const cls = w.cls || "unknown";
            if (!map[cls]) { map[cls] = []; order.push(cls); }
            map[cls].push(w);
        }

        const pinned = AppSettings.pinnedList();
        const groups = [];
        for (const cls of pinned) {
            groups.push({ cls: cls, windows: map[cls] || [], pinned: true });
        }
        for (const cls of order) {
            if (pinned.indexOf(cls) === -1) {
                groups.push({ cls: cls, windows: map[cls], pinned: false });
            }
        }
        return groups;
    }

    function findAppForClass(cls) {
        if (!cls) return null;
        const apps = DesktopEntries.applications.values;
        const lc = cls.toLowerCase();
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].id && apps[i].id.toLowerCase() === lc) return apps[i];
        }
        for (let i = 0; i < apps.length; i++) {
            const id = apps[i].id ? apps[i].id.toLowerCase() : "";
            if (id && (id.indexOf(lc) !== -1 || lc.indexOf(id) !== -1)) return apps[i];
        }
        return null;
    }

    function activateGroup(group) {
        if (group.windows.length === 0) {
            const app = root.findAppForClass(group.cls);
            if (app) app.execute();
            return;
        }
        const focused = group.windows.find(w => w.address === root.activeAddress);
        if (focused) {
            root.minimize(focused);
            return;
        }
        const hidden = group.windows.find(w => w.workspaceName && w.workspaceName.indexOf("special") === 0);
        root.bringToCurrentWorkspace(hidden || group.windows[0]);
    }

    function minimize(win) {
        root._origWorkspace[win.address] = win.workspaceId;
        Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", "special:minimized,address:" + win.address]);
    }

    // Un-minimizes / focuses a window on the workspace the user is
    // currently viewing, rather than switching the user's view to
    // wherever the window happens to live. That's the whole point of
    // clicking a dock icon: the app comes to you.
    function bringToCurrentWorkspace(win) {
        const weMinimizedIt = root._origWorkspace[win.address] !== undefined;
        delete root._origWorkspace[win.address];

        const isOtherSpecial = !weMinimizedIt && win.workspaceName && win.workspaceName.indexOf("special") === 0;
        if (isOtherSpecial) {
            // A special workspace we didn't put it in ourselves (e.g. your
            // own scratchpad) — toggling it visible already overlays the
            // current view rather than switching workspace, so no jump.
            const name = win.workspaceName === "special" ? "" : win.workspaceName.replace("special:", "");
            Quickshell.execDetached(["bash", "-c",
                "hyprctl dispatch togglespecialworkspace " + name +
                " && hyprctl dispatch focuswindow address:" + win.address]);
            return;
        }

        const target = root.activeWorkspace.id;
        Quickshell.execDetached(["bash", "-c",
            "hyprctl dispatch movetoworkspacesilent " + target + ",address:" + win.address +
            " && hyprctl dispatch focuswindow address:" + win.address]);
    }

    function closeGroup(group) {
        for (const w of group.windows) {
            Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + w.address]);
        }
    }

    function closeGroupByClass(cls) {
        const group = root.groups.find(g => g.cls === cls);
        if (group) root.closeGroup(group);
    }

    Process {
        id: winProc
        running: true
        command: [
            "bash", "-c",
            "get_state() { " +
            "  clients=$(hyprctl clients -j 2>/dev/null | tr -d '\\n'); " +
            "  active=$(hyprctl activewindow -j 2>/dev/null | tr -d '\\n'); " +
            "  aws=$(hyprctl activeworkspace -j 2>/dev/null | tr -d '\\n'); " +
            "  printf '%s\\t\\t\\t%s\\t\\t\\t%s\\n' \"$clients\" \"$active\" \"$aws\"; " +
            "}; " +
            "get_state; " +
            "stdbuf -oL socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null | " +
            "stdbuf -oL grep --line-buffered -E 'openwindow>>|closewindow>>|activewindow>>|movewindow>>|windowtitlev2>>|workspace>>' | " +
            "while read -r line; do get_state; done"
        ]
        stdout: SplitParser {
            onRead: text => {
                const clean = text.trim();
                if (!clean) return;
                const parts = clean.split("\t\t\t");
                if (parts.length < 3) return;
                const clientsStr = parts[0];
                const activeStr = parts[1];
                const awsStr = parts[2];

                try {
                    const parsed = JSON.parse(clientsStr || "[]");
                    root.windows = parsed.map(c => ({
                        // Addresses are normalized to lowercase everywhere they're
                        // read/compared (here and in activeAddress below) because
                        // `hyprctl activewindow -j` and `hyprctl clients -j` don't
                        // reliably agree on hex casing. Without this, comparing
                        // w.address === root.activeAddress could silently fail for
                        // the currently focused window, which meant clicking its
                        // dock icon never matched the "minimize" branch below and
                        // always fell through to the "bring to front" branch
                        // instead (looks like nothing happens, since it's already
                        // in front).
                        address: (c.address || "").toLowerCase(),
                        cls: c.class,
                        title: c.title,
                        workspaceId: c.workspace ? c.workspace.id : 0,
                        workspaceName: c.workspace ? c.workspace.name : ""
                    }));
                } catch (e) { }

                try {
                    const act = JSON.parse(activeStr || "{}");
                    root.activeAddress = (act.address || "").toLowerCase();
                } catch (e) { }

                try {
                    const aws = JSON.parse(awsStr || "{}");
                    if (aws.id !== undefined) root.activeWorkspace = aws;
                } catch (e) { }
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

                // Subtle top highlight, like a hairline of light catching the glass edge
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

                    readonly property bool isFocused: modelData.windows.some(w => w.address === root.activeAddress)
                    readonly property bool hasWindows: modelData.windows.length > 0
                    readonly property bool isMinimized: hasWindows && !isFocused &&
                        modelData.windows.every(w => w.workspaceName && w.workspaceName.indexOf("special") === 0)
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

                    // Running indicator dot, macOS-dock style
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

                    // Pinned marker for single-window / not-running pinned apps
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

                    // Middle-click closes the group's windows directly — the
                    // usual dock shortcut, so you don't need the right-click
                    // menu just to close a running app.
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

                    // Small floating label, macOS-dock style, instead of the
                    // generic system ToolTip control.
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
