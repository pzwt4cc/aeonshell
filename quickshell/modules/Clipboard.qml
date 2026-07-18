// Clipboard.qml

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    property var items: []

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle(); }
    }

    function toggle() {
        if (popup.shown) {
            popup.shown = false;
            return;
        }
        listProc.command = ["bash", "-c", "cliphist list | tail -30"];
        listProc.running = true;
    }

    Process {
        id: listProc
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                if (text) {
                    let newLines = text.split("\n");
                    let oldItems = root.items;
                    
                    if (oldItems.length === 0) {
                        root.items = newLines;
                    } else {
                        let oldContentMap = {};
                        for (let i = 0; i < oldItems.length; i++) {
                            let content = oldItems[i].replace(/^\d+\t/, "");
                            oldContentMap[content] = i;
                        }
                        
                        let updatedItems = new Array(oldItems.length);
                        let brandNewItems = [];
                        
                        for (let i = 0; i < newLines.length; i++) {
                            let line = newLines[i];
                            let content = line.replace(/^\d+\t/, "");
                            
                            if (content in oldContentMap) {
                                let oldIdx = oldContentMap[content];
                                updatedItems[oldIdx] = line;
                            } else {
                                brandNewItems.push(line);
                            }
                        }
                        
                        let filteredOld = updatedItems.filter(function(item) { return item !== undefined; });
                        
                        root.items = brandNewItems.concat(filteredOld);
                    }
                } else {
                    root.items = [];
                }
                popup.shown = true;
            }
        }
    }

    Process { 
        id: pickProc
        running: false
        command: [] 
        stderr: StdioCollector { 
            onStreamFinished: { console.log("PROCESS ERROR: " + this.text); } 
        }
    }

    function pick(index) {
        const line = root.items[index];
        if (!line) return;
        const id = line.split("\t")[0].trim();
        
        pickProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
        pickProc.running = true;
        
        console.log("DEBUG: Executing direct: cliphist decode " + id + " | wl-copy");
        popup.shown = false;
    }

    function wipe() {
        wipeProc.command = ["bash", "-c", "cliphist wipe"];
        wipeProc.running = true;
        root.items = [];
    }

    Process { id: wipeProc; running: false; command: [] }

    PanelWindow {
        id: popup
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: popup.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property bool shown: false
        
        Timer { id: hideTimer; interval: 320 }
        onShownChanged: {
            if (!shown) {
                hideTimer.start();
            } else {
                hideTimer.stop();
                focusRetainer.forceActiveFocus();
            }
        }
        visible: shown || hideTimer.running

        mask: shown ? null : emptyMask
        Region { id: emptyMask }

        MouseArea {
            anchors.fill: parent
            onClicked: popup.shown = false
        }

        Item {
            id: focusRetainer
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: popup.shown = false
            
            onActiveFocusChanged: {
                if (!activeFocus && popup.shown) {
                    popup.shown = false;
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
            scale: popup.shown ? 1.0 : 0.85
            opacity: popup.shown ? 1.0 : 0.0

            Behavior on scale {
                NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
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
                    GradientStop { position: 0.0; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.0) }
                    GradientStop { position: 0.5; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.85) }
                    GradientStop { position: 1.0; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.0) }
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

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 8
                        color: clearHover.hovered
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰇾"
                            color: clearHover.hovered
                                ? Colors.primary
                                : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 15
                        }

                        HoverHandler { id: clearHover }
                        TapHandler { onTapped: root.wipe() }
                    }

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 8
                        color: closeHover.hovered
                            ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 15
                        }

                        HoverHandler { id: closeHover }
                        TapHandler { onTapped: popup.shown = false }
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
                        property int itemIndex: index
                        property string clipText: modelData.replace(/^\d+\t/, "")

                        width: listView.width
                        height: Math.max(62, Math.min(contentText.implicitHeight + (contentText.lineCount > 1 ? 24 : 0), 160))
                        radius: 12
                        
                        color: mouseArea.containsMouse
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                        Text {
                            id: contentText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 14
                            anchors.rightMargin: 44
                            anchors.top: parent.top
                            anchors.topMargin: contentText.lineCount > 1 
                                ? 12 
                                : (itemDelegate.height - contentText.implicitHeight) / 2

                            text: itemDelegate.clipText
                            color: Colors.surfaceText
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            lineHeight: 1.15
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter 
                            text: "󰆏"
                            color: mouseArea.containsMouse
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.7)
                                : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.2)
                            font.pixelSize: 14
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pick(itemIndex);
                            }
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