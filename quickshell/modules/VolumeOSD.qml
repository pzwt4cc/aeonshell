// VolumeOSD.qml

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    readonly property var activeScreen: {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].isPrimary) return screens[i];
        }
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].x === 0 && screens[i].y === 0) return screens[i];
        }
        return screens[0];
    }
    screen: root.activeScreen

    readonly property bool vertical: AppSettings.barPosition === "left" || AppSettings.barPosition === "right"
    readonly property bool atBottom: AppSettings.barPosition === "bottom"
    readonly property bool atRight: AppSettings.barPosition === "right"

    readonly property int barThickness: 48
    readonly property int barMargin: AppSettings.edgeToEdge ? 0 : 8
    readonly property int gap: 3
    readonly property int offset: root.barThickness + root.barMargin + root.gap

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
    Region { id: emptyMask }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!(root.sink && root.sink.audio && root.sink.audio.muted)
    readonly property real volume: (root.sink && root.sink.audio) ? root.sink.audio.volume : 0

    readonly property real maxVolume: 1.5
    readonly property int volumePct: Math.round(root.volume * 100)
    readonly property bool boosted: root.volumePct > 100
    readonly property real fillFraction: root.muted ? 0 : Math.min(1, root.volume)

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    property bool shown: false

    property bool _ready: false
    Timer { interval: 600; running: true; onTriggered: root._ready = true }

    function _pop() {
        if (!root._ready) return;
        if (AppSettings.suppressVolumeOSD) return;
        root.shown = true;
        hideTimer.restart();
    }

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { root._pop() }
        function onMutedChanged() { root._pop() }
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: root.shown = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? 56 : 220
        height: root.vertical ? 220 : 56
        radius: 16
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.85)
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1

        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.9
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        ColumnLayout {
            visible: root.vertical
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: (root.muted || root.volumePct === 0) ? "󰖁" : "󰕾"
                color: root.muted
                    ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                    : Colors.surfaceText
                font.pixelSize: 18
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 8
                    height: parent.height * root.fillFraction
                    radius: 4
                    color: root.boosted ? (Colors.warning ?? "#e0a030") : Colors.primary
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: parent.width * root.fillFraction
                    height: 8
                    radius: 4
                    color: root.boosted ? (Colors.warning ?? "#e0a030") : Colors.primary
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.muted ? "Mute" : (root.volumePct + "%")
                color: root.boosted ? (Colors.warning ?? "#e0a030") : Colors.surfaceText
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
                color: root.muted
                    ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                    : Colors.surfaceText
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
                    color: root.boosted ? (Colors.warning ?? "#e0a030") : Colors.primary
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }
            }

            Text {
                text: root.muted ? "Mute" : (root.volumePct + "%")
                color: root.boosted ? (Colors.warning ?? "#e0a030") : Colors.surfaceText
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 34
            }
        }
    }
}