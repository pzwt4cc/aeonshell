// AudioButton.qml

import "../"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Rectangle {
    id: root

    property bool vertical: false
    property bool active: false

    signal clicked

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property int volumePct: Math.round(Math.min(1.5, Math.max(0, volume)) * 100)

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    readonly property string iconGlyph: {
        if (root.muted || root.volumePct === 0)
            return "󰖁";
        if (root.volumePct < 33)
            return "󰕿";
        if (root.volumePct < 67)
            return "󰖀";
        return "󰕾";
    }

    Layout.preferredWidth: root.vertical ? 32 : Math.max(32, contentRow.implicitWidth + 14)
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    radius: 8
    color: root.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2) : (btnMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent")
    border.color: root.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : "transparent"
    border.width: 1

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.iconGlyph
            font.pixelSize: 15
            color: root.active ? Colors.primary : (root.muted ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45) : (btnMa.containsMouse ? Colors.surfaceText : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.8)))
            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Text {
            visible: !root.vertical
            text: root.muted ? "Mute" : (root.volumePct + "%")
            font.pixelSize: 11
            font.bold: true
            color: root.active ? Colors.primary : (root.muted ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.8))
            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }
    }

    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        property real wheelAccum: 0

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.sink && root.sink.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            } else {
                root.clicked();
            }
        }

        onWheel: wheel => {
            if (!root.sink || !root.sink.audio)
                return;
            wheelAccum += wheel.angleDelta.y;
            const threshold = 120;
            if (Math.abs(wheelAccum) >= threshold) {
                const steps = Math.trunc(wheelAccum / threshold);
                wheelAccum = wheelAccum % threshold;
                if (steps !== 0) {
                    const nextVol = Math.max(0, Math.min(1.0, root.sink.audio.volume + steps * 0.05));
                    root.sink.audio.volume = nextVol;
                    if (nextVol > 0 && root.sink.audio.muted)
                        root.sink.audio.muted = false;
                }
            }
        }
    }
}
