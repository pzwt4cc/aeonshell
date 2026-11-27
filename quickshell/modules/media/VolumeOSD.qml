// VolumeOSD.qml

pragma ComponentBehavior: Bound

import "../"
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    readonly property var activeScreen: {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].isPrimary)
                return screens[i];
        }
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].x === 0 && screens[i].y === 0)
                return screens[i];
        }
        return screens[0] || null;
    }

    readonly property bool vertical: AppSettings.barPosition === "left" || AppSettings.barPosition === "right"
    readonly property bool atBottom: AppSettings.barPosition === "bottom"
    readonly property bool atRight: AppSettings.barPosition === "right"

    readonly property int barThickness: 48
    readonly property int barMargin: AppSettings.edgeToEdge ? 0 : 8
    readonly property int gap: 3
    readonly property int offset: root.barThickness + root.barMargin + root.gap

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!(root.sink && root.sink.audio && root.sink.audio.muted)
    readonly property real volume: (root.sink && root.sink.audio) ? root.sink.audio.volume : 0

    readonly property int volumePct: Math.round(root.volume * 100)
    readonly property bool boosted: root.volumePct > 100
    readonly property real fillFraction: root.muted ? 0 : Math.min(1, root.volume)

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    property bool shown: false
    property bool _armed: false

    Timer {
        id: armTimer
        interval: 250
        running: true
        onTriggered: root._armed = true
    }

    onSinkChanged: {
        root._armed = false;
        armTimer.restart();
    }

    function _pop() {
        if (!root._armed)
            return;
        if (ShellState.suppressVolumeOSD)
            return;
        root.shown = true;
        hideTimer.restart();
    }

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() {
            root._pop();
        }
        function onMutedChanged() {
            root._pop();
        }
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: root.shown = false
    }

    Timer {
        id: closeLinger
        interval: 180
    }

    onShownChanged: {
        if (!shown)
            closeLinger.restart();
        else
            closeLinger.stop();
    }

    LazyLoader {
        id: osdLoader
        active: root.shown || closeLinger.running

        PanelWindow {
            id: osdWin
            screen: root.activeScreen

            anchors {
                top: root.vertical ? true : !root.atBottom
                bottom: root.vertical ? true : root.atBottom
                left: root.vertical ? !root.atRight : true
                right: root.vertical ? root.atRight : true
            }
            margins.top: root.vertical ? 0 : (root.atBottom ? 0 : root.offset)
            margins.bottom: root.vertical ? 0 : (root.atBottom ? root.offset : 0)
            margins.left: root.vertical ? (root.atRight ? 0 : root.offset) : 0
            margins.right: root.vertical ? (root.atRight ? root.offset : 0) : 0

            implicitWidth: root.vertical ? 56 : 220
            implicitHeight: root.vertical ? 220 : 56

            color: "transparent"
            visible: true
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: emptyMask
            Region {
                id: emptyMask
            }

            property bool _animReady: false
            Component.onCompleted: Qt.callLater(function () {
                osdWin._animReady = true;
            })

            Rectangle {
                anchors.centerIn: parent
                width: root.vertical ? 56 : 220
                height: root.vertical ? 220 : 56
                radius: 16
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, AppSettings.popupOpacity)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                opacity: (root.shown && osdWin._animReady) ? 1.0 : 0.0
                scale: (root.shown && osdWin._animReady) ? 1.0 : 0.9
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    visible: root.vertical
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (root.muted || root.volumePct === 0) ? "󰖁" : "󰕾"
                        color: root.muted ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45) : Colors.surfaceText
                        font.pixelSize: 18
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 8
                            radius: 4
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 8
                            height: parent.height * root.fillFraction
                            radius: 4
                            color: root.boosted ? "#e0a030" : Colors.primary
                            Behavior on height {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.muted ? "Mute" : (root.volumePct + "%")
                        color: root.boosted ? "#e0a030" : Colors.surfaceText
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                RowLayout {
                    visible: !root.vertical
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        text: (root.muted || root.volumePct === 0) ? "󰖁" : "󰕾"
                        color: root.muted ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45) : Colors.surfaceText
                        font.pixelSize: 18
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 8
                            radius: 4
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            width: parent.width * root.fillFraction
                            height: 8
                            radius: 4
                            color: root.boosted ? "#e0a030" : Colors.primary
                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }

                    Text {
                        text: root.muted ? "Mute" : (root.volumePct + "%")
                        color: root.boosted ? "#e0a030" : Colors.surfaceText
                        font.pixelSize: 12
                        font.bold: true
                        Layout.preferredWidth: 34
                    }
                }
            }
        }
    }
}
