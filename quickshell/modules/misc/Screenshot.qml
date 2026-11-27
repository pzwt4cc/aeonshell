// Screenshot.qml

import "../"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    readonly property string shotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property string shotPath: ""
    property bool resultShown: false

    Timer {
        id: hideTimer
        interval: 260
    }
    onResultShownChanged: {
        if (!resultShown)
            hideTimer.start();
        else
            hideTimer.stop();
    }

    Timer {
        id: autoHide
        interval: 7000
        onTriggered: root.resultShown = false
    }

    function showResult(path) {
        root.shotPath = path;
        root.resultShown = true;
        autoHide.restart();
    }

    IpcHandler {
        id: ipc
        target: "screenshot"
        function region(): void {
            root.takeRegion();
        }
        function full(): void {
            root.takeFull();
        }
        function _report(path: string): void {
            if (path.length > 0)
                root.showResult(path);
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
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && f=\"$1/shot_$(date +%Y%m%d_%H%M%S).png\" && " + "geo=$(slurp -b '#00000066' -c \"$2\" -w 2 2>/dev/null) && [ -n \"$geo\" ] && " + "grim -g \"$geo\" \"$f\" 2>/dev/null && qs ipc call screenshot _report \"$f\"", "sh", root.shotsDir, "#" + accent + "dd"]);
    }

    function takeFull() {
        const monObj = Hyprland.focusedMonitor;
        const monName = monObj ? monObj.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && f=\"$1/shot_$(date +%Y%m%d_%H%M%S).png\" && " + "{ if [ -n \"$2\" ]; then grim -o \"$2\" \"$f\"; else grim \"$f\"; fi; } 2>/dev/null && " + "qs ipc call screenshot _report \"$f\"", "sh", root.shotsDir, monName]);
    }

    Process {
        id: copyProc
        running: false
        command: []
    }
    Process {
        id: deleteProc
        running: false
        command: []
    }

    LazyLoader {
        id: resultLoader
        active: root.resultShown || hideTimer.running

        PanelWindow {
            id: resultPanel
            anchors {
                top: true
                right: true
            }
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            visible: true

            mask: root.resultShown ? null : emptyMask
            Region {
                id: emptyMask
            }

            implicitWidth: 380
            implicitHeight: card.implicitHeight + 32

            property bool _animReady: false
            Component.onCompleted: Qt.callLater(function () {
                _animReady = true;
            })

            Rectangle {
                id: card
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                width: 348
                implicitHeight: content.implicitHeight + 26
                radius: 20
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, AppSettings.popupOpacity)
                border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.25)
                border.width: 1
                clip: true

                opacity: (root.resultShown && resultPanel._animReady) ? 1.0 : 0.0
                y: (root.resultShown && resultPanel._animReady) ? 0 : -24
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            autoHide.stop();
                        else
                            autoHide.restart();
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
                                source: root.shotPath ? "file://" + root.shotPath : ""
                                sourceSize: Qt.size(112, 112)
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
                                text: root.shotPath.split("/").pop()
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
                            TapHandler {
                                onTapped: root.resultShown = false
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ActionButton {
                            icon: "󰆏"
                            label: "Copy"
                            onClicked: {
                                copyProc.command = ["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", root.shotPath];
                                copyProc.running = true;
                                root.resultShown = false;
                            }
                        }
                        ActionButton {
                            icon: "󰏫"
                            label: "Edit"
                            onClicked: {
                                Quickshell.execDetached(["swappy", "-f", root.shotPath]);
                                root.resultShown = false;
                            }
                        }
                        ActionButton {
                            icon: "󰝰"
                            label: "Folder"
                            onClicked: {
                                Quickshell.execDetached(["pcmanfm-qt", root.shotsDir]);
                                root.resultShown = false;
                            }
                        }
                        ActionButton {
                            icon: "󰩹"
                            label: "Delete"
                            onClicked: {
                                deleteProc.command = ["rm", "-f", root.shotPath];
                                deleteProc.running = true;
                                root.resultShown = false;
                            }
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
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: 14
        color: hover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

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

        HoverHandler {
            id: hover
        }
        TapHandler {
            onTapped: btn.clicked()
        }
    }
}
