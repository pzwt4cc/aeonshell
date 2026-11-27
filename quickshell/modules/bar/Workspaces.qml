// Workspaces.qml

import "../"
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Rectangle {
    id: root

    property bool vertical: false

    readonly property int totalWorkspaces: 5
    readonly property int dotSize: 10
    readonly property int spacing: 18
    readonly property int edgePadding: 16

    readonly property int ghostSize: 20
    readonly property int ghostSpacing: 14

    readonly property int rowLength: (totalWorkspaces * dotSize) + ((totalWorkspaces - 1) * spacing)
    readonly property int rowStart: edgePadding + ghostSize + ghostSpacing

    implicitWidth: root.vertical ? 32 : (rowStart + rowLength + edgePadding)
    implicitHeight: root.vertical ? (rowStart + rowLength + edgePadding) : 32
    Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter

    radius: 8
    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
    border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
    border.width: 1

    property int activeWorkspace: 1
    property int lastWorkspace: 1
    property real rotationAngle: 0
    property bool specialActive: false
    property bool specialOccupied: false

    // Keep Hyprland IPC reactive
    readonly property var _hyKeepAlive: Hyprland.monitors

    function syncState() {
        const fw = Hyprland.focusedWorkspace;
        if (fw && fw.id >= 1 && fw.id <= root.totalWorkspaces) {
            root.activeWorkspace = fw.id;
        }

        let hasActiveSpecial = false;
        const mons = Hyprland.monitors.values;
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            const sw = m && m.lastIpcObject ? m.lastIpcObject.specialWorkspace : null;
            if (sw && ((sw.id !== undefined && sw.id !== 0) || (sw.name || "") !== "")) {
                hasActiveSpecial = true;
                break;
            }
        }
        root.specialActive = hasActiveSpecial;

        let hasOccupiedSpecial = false;
        const wss = Hyprland.workspaces.values;
        for (let i = 0; i < wss.length; i++) {
            const w = wss[i];
            const ipc = w ? w.lastIpcObject : null;
            const name = w ? (w.name || (ipc && ipc.name) || "") : "";
            const wins = ipc && ipc.windows !== undefined ? ipc.windows : 0;
            if (name.indexOf("special") === 0 && wins > 0) {
                hasOccupiedSpecial = true;
                break;
            }
        }
        root.specialOccupied = hasOccupiedSpecial;
    }

    onActiveWorkspaceChanged: {
        if (activeWorkspace > lastWorkspace) {
            rotationAnimation.to = rotationAngle + 360;
        } else if (activeWorkspace < lastWorkspace) {
            rotationAnimation.to = rotationAngle - 360;
        }
        rotationAnimation.start();
        lastWorkspace = activeWorkspace;
    }

    Timer {
        id: syncDebounce
        interval: 25
        onTriggered: root.syncState()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "workspace" || n === "workspacev2" || n === "focusedmon" || n === "focusedmonv2" || n === "activespecial" || n === "activespecialv2" || n === "createworkspace" || n === "createworkspacev2" || n === "destroyworkspace" || n === "destroyworkspacev2" || n === "movewindow" || n === "movewindowv2" || n === "openwindow" || n === "closewindow") {
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
                syncDebounce.restart();
            }
        }
        function onFocusedWorkspaceChanged() {
            syncDebounce.restart();
        }
    }

    Component.onCompleted: {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        syncState();
    }

    Text {
        id: ghost
        text: "󰊠"
        font.pixelSize: 20
        width: root.ghostSize
        height: root.ghostSize
        x: root.vertical ? (parent.width - width) / 2 : root.edgePadding
        y: root.vertical ? root.edgePadding : (parent.height - height) / 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        color: root.specialActive ? Colors.primary : (root.specialOccupied ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25))

        opacity: root.specialActive ? pulseAnim.value : (ghostHover.hovered ? 1.0 : 0.7)

        scale: ghostHover.hovered ? 1.15 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }

        QtObject {
            id: pulseAnim
            property real value: 1.0
            SequentialAnimation on value {
                running: root.specialActive
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.5
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    to: 1.0
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
            }
        }

        HoverHandler {
            id: ghostHover
        }

        TapHandler {
            onTapped: Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.workspace.toggle_special()" : "togglespecialworkspace")
        }
    }

    component Dot: Rectangle {
        id: dot
        required property int index
        width: root.dotSize
        height: root.dotSize
        radius: width / 2
        color: Colors.primary

        readonly property bool isCurrent: (index + 1) === root.activeWorkspace
        opacity: isCurrent ? 0.0 : (dotHover.hovered ? 0.75 : 0.3)

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        HoverHandler {
            id: dotHover
        }

        TapHandler {
            onTapped: {
                const ws = dot.index + 1;
                Hyprland.dispatch(Hyprland.usingLua ? ("hl.dsp.focus({ workspace = " + ws + " })") : ("workspace " + ws));
            }
        }
    }

    Grid {
        x: root.vertical ? (parent.width - width) / 2 : root.rowStart
        y: root.vertical ? root.rowStart : (parent.height - height) / 2
        rows: root.vertical ? root.totalWorkspaces : 1
        columns: root.vertical ? 1 : root.totalWorkspaces
        spacing: root.spacing

        Repeater {
            model: root.totalWorkspaces
            delegate: Dot {}
        }
    }

    Text {
        id: pacman
        text: "󰚀"
        font.pixelSize: 20
        color: Colors.primary
        width: 20
        height: 20
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        x: root.vertical ? (parent.width - width) / 2 : root.rowStart + (root.activeWorkspace - 1) * (root.dotSize + root.spacing) + (root.dotSize / 2) - (width / 2)
        y: root.vertical ? root.rowStart + (root.activeWorkspace - 1) * (root.dotSize + root.spacing) + (root.dotSize / 2) - (height / 2) : (parent.height - height) / 2

        rotation: root.rotationAngle
        transformOrigin: Item.Center

        Behavior on x {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }

    NumberAnimation {
        id: rotationAnimation
        target: root
        property: "rotationAngle"
        duration: 400
        easing.type: Easing.OutCubic
    }
}
