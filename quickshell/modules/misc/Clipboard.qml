// Clipboard.qml

import "../"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    property var items: []
    property bool shown: false

    Timer {
        id: hideTimer
        interval: 320
    }
    onShownChanged: {
        if (!shown)
            hideTimer.start();
        else
            hideTimer.stop();
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            root.toggle();
        }
    }

    function toggle() {
        if (root.shown) {
            root.shown = false;
            return;
        }
        listProc.command = ["sh", "-c", "cliphist list | head -n 40"];
        listProc.running = true;
    }

    Process {
        id: listProc
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                if (!text) {
                    root.items = [];
                    root.shown = true;
                    return;
                }
                const newLines = text.split("\n");
                const oldItems = root.items;
                if (oldItems.length === 0) {
                    root.items = newLines;
                } else {
                    const oldContentMap = Object.create(null);
                    for (let i = 0; i < oldItems.length; i++) {
                        const content = oldItems[i].replace(/^\d+\t/, "");
                        oldContentMap[content] = i;
                    }
                    const updatedItems = new Array(oldItems.length);
                    const brandNewItems = [];
                    for (let i = 0; i < newLines.length; i++) {
                        const line = newLines[i];
                        const content = line.replace(/^\d+\t/, "");
                        if (Object.prototype.hasOwnProperty.call(oldContentMap, content)) {
                            updatedItems[oldContentMap[content]] = line;
                        } else {
                            brandNewItems.push(line);
                        }
                    }
                    const filteredOld = updatedItems.filter(function (item) {
                        return item !== undefined;
                    });
                    root.items = brandNewItems.concat(filteredOld);
                }
                root.shown = true;
            }
        }
    }

    Process {
        id: pickProc
        running: false
        command: []
        stderr: StdioCollector {
            onStreamFinished: {
                const err = this.text.trim();
                if (err)
                    console.log("[Clipboard] error:", err);
            }
        }
    }

    function pick(index) {
        const line = root.items[index];
        if (!line)
            return;
        const id = line.split("\t")[0].trim();
        if (!/^\d+$/.test(id))
            return;

        pickProc.command = ["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id];
        pickProc.running = true;
        root.shown = false;
    }

    function wipe() {
        wipeProc.command = ["cliphist", "wipe"];
        wipeProc.running = true;
        root.items = [];
    }

    Process {
        id: wipeProc
        running: false
        command: []
    }

    LazyLoader {
        id: popupLoader
        active: root.shown || hideTimer.running

        PanelWindow {
            id: popup
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            visible: true
            mask: root.shown ? null : emptyMask
            Region {
                id: emptyMask
            }

            property bool _animReady: false
            Component.onCompleted: Qt.callLater(function () {
                _animReady = true;
                focusRetainer.forceActiveFocus();
            })

            Connections {
                target: root
                function onShownChanged() {
                    if (root.shown)
                        focusRetainer.forceActiveFocus();
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }

            Item {
                id: focusRetainer
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.shown = false

                onActiveFocusChanged: {
                    if (!activeFocus && root.shown) {
                        root.shown = false;
                    }
                }
            }

            Rectangle {
                anchors.fill: card
                anchors.margins: -4
                radius: card.radius + 4
                color: Qt.rgba(0, 0, 0, 0.4)
                opacity: card.opacity * 0.35
                scale: card.scale
                transformOrigin: Item.Center
                z: -1
            }

            Rectangle {
                id: card
                width: 640
                height: 560
                anchors.centerIn: parent
                radius: 28
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
                border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
                border.width: 1
                clip: true

                transformOrigin: Item.Center
                scale: (root.shown && popup._animReady) ? 1.0 : 0.85
                opacity: (root.shown && popup._animReady) ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.15
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.28
                    height: 3
                    radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.0)
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.85)
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.0)
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    anchors.topMargin: 30
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 11
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.10)

                            Text {
                                anchors.centerIn: parent
                                text: "\uf328"
                                color: Colors.primary
                                font.pixelSize: 20
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: "Clipboard"
                                color: Colors.surfaceText
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                text: root.items.length + " items"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                font.pixelSize: 12
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 8
                            color: clearHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰇾"
                                color: clearHover.hovered ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 15
                            }

                            HoverHandler {
                                id: clearHover
                            }
                            TapHandler {
                                onTapped: root.wipe()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 8
                            color: closeHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 15
                            }

                            HoverHandler {
                                id: closeHover
                            }
                            TapHandler {
                                onTapped: root.shown = false
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                    }

                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.items
                        spacing: 6

                        delegate: Rectangle {
                            id: itemDelegate
                            required property string modelData
                            required property int index
                            property string clipText: modelData.replace(/^\d+\t/, "")

                            width: listView.width
                            height: Math.max(62, Math.min(contentText.implicitHeight + (contentText.lineCount > 1 ? 24 : 0), 160))
                            radius: 12
                            clip: true

                            color: mouseArea.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12) : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Text {
                                id: contentText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 14
                                anchors.rightMargin: 44
                                anchors.top: parent.top
                                anchors.topMargin: contentText.lineCount > 1 ? 12 : (itemDelegate.height - contentText.implicitHeight) / 2

                                text: itemDelegate.clipText
                                color: Colors.surfaceText
                                font.pixelSize: 14
                                wrapMode: Text.Wrap
                                maximumLineCount: 6
                                elide: Text.ElideRight
                                lineHeight: 1.15
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰆏"
                                color: mouseArea.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.7) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.2)
                                font.pixelSize: 14
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pick(itemDelegate.index)
                            }
                        }
                    }

                    Text {
                        text: root.items.length === 0 ? "Clipboard is empty" : ""
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                        font.pixelSize: 15
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        visible: root.items.length === 0
                    }
                }
            }
        }
    }
}
