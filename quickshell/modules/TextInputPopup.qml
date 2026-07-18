// TextInputPopup.qml
//
// Custom-themed replacement for `zenity --entry`. Small modal window
// styled like the rest of aeonshell — a label, a text field pre-filled
// with the current value, and Cancel / Save buttons.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

FloatingWindow {
    id: popup

    property string popupTitle: "Enter Value"
    property string promptText: ""
    property string currentValue: ""

    signal accepted(string value)
    signal rejected()

    function openWith(value) {
        popup.currentValue = value || "";
        field.text = popup.currentValue;
        popup.visible = true;
        field.forceActiveFocus();
        field.selectAll();
    }

    title: popupTitle
    visible: false
    color: "transparent"
    implicitWidth: 380
    implicitHeight: 180

    onClosed: {
        popup.rejected();
        popup.visible = false;
    }

    Rectangle {
        id: winBg
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.98)
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 30
                    cursorShape: Qt.SizeAllCursor
                    onPressed: mouse => popup.startSystemMove()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.popupTitle
                    color: Colors.surfaceText
                    font.pixelSize: 15
                    font.bold: true
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 8
                    color: closeHover.hovered ? Qt.rgba(1, 0.3, 0.3, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: closeHover }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: Colors.surfaceText
                        font.pixelSize: 12
                    }

                    TapHandler {
                        onTapped: {
                            popup.rejected();
                            popup.visible = false;
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: popup.promptText
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                visible: popup.promptText.length > 0
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 10
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                border.color: field.activeFocus ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextField {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.surfaceText
                    font.pixelSize: 14
                    background: null
                    selectByMouse: true

                    Keys.onReturnPressed: confirmBtn.trigger()
                    Keys.onEnterPressed: confirmBtn.trigger()
                    Keys.onEscapePressed: {
                        popup.rejected();
                        popup.visible = false;
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 90
                    height: 34
                    radius: 10
                    color: cancelHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)

                    HoverHandler { id: cancelHover }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Colors.surfaceText
                        font.pixelSize: 13
                    }

                    TapHandler {
                        onTapped: {
                            popup.rejected();
                            popup.visible = false;
                        }
                    }
                }

                Rectangle {
                    id: confirmBtn
                    width: 90
                    height: 34
                    radius: 10
                    opacity: field.text.trim().length > 0 ? 1.0 : 0.4
                    color: Colors.primary

                    function trigger() {
                        if (field.text.trim().length === 0) return;
                        popup.accepted(field.text.trim());
                        popup.visible = false;
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: Colors.background
                        font.pixelSize: 13
                        font.bold: true
                    }

                    TapHandler {
                        enabled: field.text.trim().length > 0
                        onTapped: confirmBtn.trigger()
                    }
                }
            }
        }
    }
}