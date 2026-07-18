// Workspaces.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

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

    onActiveWorkspaceChanged: {
        if (activeWorkspace > lastWorkspace) {
            rotationAnimation.to = rotationAngle + 360;
        } else if (activeWorkspace < lastWorkspace) {
            rotationAnimation.to = rotationAngle - 360;
        }
        rotationAnimation.start();
        lastWorkspace = activeWorkspace;
    }

    Process {
        id: wsProc
        running: true
        command: [
            "bash", "-c",
            "get_state() { " +
            "  active=$(echo \"$(hyprctl activeworkspace -j 2>/dev/null || echo '{\"id\":1}')\" | tr -d '\\n'); " +
            "  monitors=$(echo \"$(hyprctl monitors -j 2>/dev/null || echo '[]')\" | tr -d '\\n'); " +
            "  workspaces=$(echo \"$(hyprctl workspaces -j 2>/dev/null || echo '[]')\" | tr -d '\\n'); " +
            "  echo \"$active|$monitors|$workspaces\"; " +
            "}; " +
            "get_state; " +
            "stdbuf -oL socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null | stdbuf -oL grep --line-buffered -E 'workspace>>|activespecial>>|createworkspace>>|destroyworkspace>>|movewindow>>|openwindow>>|closewindow>>' | " +
            "while read -r line; do " +
            "  get_state; " +
            "done"
        ]

        stdout: SplitParser {
            onRead: text => {
                let clean = text.trim();
                if (!clean) return;
                let parts = clean.split('|');
                if (parts.length < 3) return;

                try {
                    let activeObj = JSON.parse(parts[0]);
                    let val = parseInt(activeObj.id);
                    if (!isNaN(val) && val >= 1 && val <= root.totalWorkspaces) {
                        root.activeWorkspace = val;
                    }
                } catch (err) { }

                try {
                    let monitorsArr = JSON.parse(parts[1]);
                    let hasActiveSpecial = false;
                    for (let i = 0; i < monitorsArr.length; i++) {
                        let mon = monitorsArr[i];
                        if (mon.specialWorkspace && mon.specialWorkspace.id !== 0) {
                            hasActiveSpecial = true;
                            break;
                        }
                    }
                    root.specialActive = hasActiveSpecial;
                } catch (err) { }

                try {
                    let workspacesArr = JSON.parse(parts[2]);
                    let hasOccupiedSpecial = false;
                    for (let i = 0; i < workspacesArr.length; i++) {
                        let ws = workspacesArr[i];
                        if (ws.name && ws.name.indexOf("special") === 0 && ws.windows > 0) {
                            hasOccupiedSpecial = true;
                            break;
                        }
                    }
                    root.specialOccupied = hasOccupiedSpecial;
                } catch (err) { }
            }
        }
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

        color: root.specialActive
            ? Colors.primary
            : (root.specialOccupied ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25))

        opacity: root.specialActive ? pulseAnim.value : (ghostHover.hovered ? 1.0 : 0.7)

        scale: ghostHover.hovered ? 1.15 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
        Behavior on color { ColorAnimation { duration: 180 } }

        QtObject {
            id: pulseAnim
            property real value: 1.0
            SequentialAnimation on value {
                running: root.specialActive
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 600; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
            }
        }

        HoverHandler { id: ghostHover }

        TapHandler {
            onTapped: {
                switchProc.command = ["hyprctl", "dispatch", "togglespecialworkspace"];
                switchProc.running = true;
            }
        }
    }

    component Dot: Rectangle {
        id: dot
        width: root.dotSize
        height: root.dotSize
        radius: width / 2
        color: Colors.primary

        readonly property bool isCurrent: (index + 1) === root.activeWorkspace
        opacity: isCurrent ? 0.0 : (dotHover.hovered ? 0.75 : 0.3)

        Behavior on opacity { NumberAnimation { duration: 120 } }

        HoverHandler { id: dotHover }

        TapHandler {
            onTapped: {
                switchProc.command = ["hyprctl", "dispatch", "workspace", (index + 1).toString()];
                switchProc.running = true;
            }
        }
    }

    Row {
        visible: !root.vertical
        enabled: !root.vertical
        x: root.rowStart
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Repeater {
            model: root.totalWorkspaces
            delegate: Dot {}
        }
    }

    Column {
        visible: root.vertical
        enabled: root.vertical
        y: root.rowStart
        anchors.horizontalCenter: parent.horizontalCenter
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

        x: root.vertical
            ? (parent.width - width) / 2
            : root.rowStart + (root.activeWorkspace - 1) * (root.dotSize + root.spacing) + (root.dotSize / 2) - (width / 2)
        y: root.vertical
            ? root.rowStart + (root.activeWorkspace - 1) * (root.dotSize + root.spacing) + (root.dotSize / 2) - (height / 2)
            : (parent.height - height) / 2

        rotation: root.rotationAngle
        transformOrigin: Item.Center

        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }

    NumberAnimation {
        id: rotationAnimation
        target: root
        property: "rotationAngle"
        duration: 400
        easing.type: Easing.OutCubic
    }

    Process {
        id: switchProc
    }
}