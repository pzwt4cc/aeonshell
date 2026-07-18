// Screenshot.qml

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    readonly property string shotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

    IpcHandler {
        id: ipc
        target: "screenshot"
        function region(): void { root.takeRegion(); }
        function full(): void { root.takeFull(); }
        function _report(path: string): void {
            if (path.length > 0) resultPanel.showResult(path);
        }
    }

    function hex(c) {
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0");
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0");
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0");
        return r + g + b;
    }

    function takeRegion() {
        const accent = root.hex(Colors.primary);
        const log = root.shotsDir + "/.region-debug.log";
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p "${root.shotsDir}"; ` +
            `f="${root.shotsDir}/shot_$(date +%Y%m%d_%H%M%S).png"; ` +
            `geo=$(slurp -b '#00000066' -c '#${accent}dd' -w 2 2>>"${log}"); ` +
            `[ -z "$geo" ] && exit 0; ` +
            `grim -g "$geo" "$f" 2>>"${log}" && qs ipc call screenshot _report "$f"`
        ]);
    }

    function takeFull() {
        const log = root.shotsDir + "/.region-debug.log";
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p "${root.shotsDir}"; ` +
            `f="${root.shotsDir}/shot_$(date +%Y%m%d_%H%M%S).png"; ` +
            `monitor=$(hyprctl activeworkspace -j | jq -r '.monitor'); ` +
            `[ -z "$monitor" ] && monitor=$(hyprctl monitors -j | jq -r '.[0].name'); ` +
            `grim -o "$monitor" "$f" 2>>"${log}" && qs ipc call screenshot _report "$f"`
        ]);
    }

    Process { id: copyProc; running: false; command: [] }
    Process { id: editProc; running: false; command: [] }
    Process { id: folderProc; running: false; command: [] }
    Process { id: deleteProc; running: false; command: [] }

    PanelWindow {
        id: resultPanel
        anchors { top: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay

        property string shotPath: ""
        property bool shown: false

        Timer { id: hideTimer; interval: 260 }
        onShownChanged: {
            if (!shown) hideTimer.start();
            else hideTimer.stop();
        }
        visible: shown || hideTimer.running

        mask: shown ? null : emptyMask
        Region { id: emptyMask }

        implicitWidth: 380
        implicitHeight: card.implicitHeight + 32

        function showResult(path) {
            resultPanel.shotPath = path;
            resultPanel.shown = true;
            autoHide.restart();
        }

        Timer {
            id: autoHide
            interval: 7000
            onTriggered: resultPanel.shown = false
        }

        Rectangle {
            id: card
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 16
            width: 348
            implicitHeight: content.implicitHeight + 26
            radius: 20
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
            border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.25)
            border.width: 1
            clip: true

            opacity: resultPanel.shown ? 1.0 : 0.0
            y: resultPanel.shown ? 0 : -24
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) autoHide.stop();
                    else autoHide.restart();
                }
            }

            ColumnLayout {
                id: content
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: 12
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: resultPanel.shotPath ? "file://" + resultPanel.shotPath : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Screenshot saved"
                            color: Colors.surfaceText
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            text: resultPanel.shotPath.split("/").pop()
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: "󰅖"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignTop
                        TapHandler { onTapped: resultPanel.shown = false }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ActionButton {
                        icon: "󰆏"
                        label: "Copy"
                        onClicked: {
                            copyProc.command = ["bash", "-c", `wl-copy --type image/png < "${resultPanel.shotPath}"`];
                            copyProc.running = true;
                            resultPanel.shown = false;
                        }
                    }
                    ActionButton {
                        icon: "󰏫"
                        label: "Edit"
                        onClicked: {
                            editProc.command = ["swappy", "-f", resultPanel.shotPath];
                            editProc.running = true;
                            resultPanel.shown = false;
                        }
                    }
                    ActionButton {
                        icon: "󰝰"
                        label: "Folder"
                        onClicked: {
                            folderProc.command = ["pcmanfm-qt", root.shotsDir];
                            folderProc.running = true;
                            resultPanel.shown = false;
                        }
                    }
                    ActionButton {
                        icon: "󰩹"
                        label: "Delete"
                        onClicked: {
                            deleteProc.command = ["rm", "-f", resultPanel.shotPath];
                            deleteProc.running = true;
                            resultPanel.shown = false;
                        }
                    }
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: btn
        property string icon: ""
        property string label: ""
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: 14
        color: hover.hovered
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16)
            : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
        Behavior on color { ColorAnimation { duration: 100 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 3
            Text {
                text: btn.icon
                color: hover.hovered ? Colors.primary : Colors.surfaceText
                font.pixelSize: 17
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: btn.label
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
            }
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: btn.clicked() }
    }
}