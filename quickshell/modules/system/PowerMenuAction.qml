// PowerMenuAction.qml

import "../"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root
    property string glyph: ""
    property string label: ""
    property var command: []
    property bool danger: false
    property bool stretched: false

    signal activated

    readonly property color accentColor: danger ? Colors.error : Colors.primary

    Layout.preferredWidth: stretched ? -1 : 84
    Layout.preferredHeight: stretched ? 66 : 84
    Layout.fillWidth: stretched

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18
        color: hover.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.14) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.045)
        border.color: hover.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
        border.width: 1
        scale: tap.pressed ? 0.96 : (hover.hovered ? 1.03 : 1.0)
        Behavior on color {
            ColorAnimation {
                duration: 130
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 130
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutBack
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            visible: !root.stretched

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 40
                height: 40
                radius: 20
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, hover.hovered ? 0.22 : 0.14)
                Behavior on color {
                    ColorAnimation {
                        duration: 130
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.glyph
                    font.pixelSize: 19
                    color: root.accentColor
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.label
                font.pixelSize: 11
                font.bold: true
                color: hover.hovered ? Colors.surfaceText : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                Behavior on color {
                    ColorAnimation {
                        duration: 130
                    }
                }
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 10
            visible: root.stretched

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, hover.hovered ? 0.22 : 0.14)
                Behavior on color {
                    ColorAnimation {
                        duration: 130
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.glyph
                    font.pixelSize: 16
                    color: root.accentColor
                }
            }

            Text {
                text: root.label
                font.pixelSize: 12
                font.bold: true
                color: hover.hovered ? Colors.surfaceText : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                Behavior on color {
                    ColorAnimation {
                        duration: 130
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        id: tap
        onTapped: {
            proc.running = true;
            root.activated();
        }
    }

    Process {
        id: proc
        command: root.command
    }
}
