// ToastCard.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: card
    property var notif

    width: 400
    Layout.preferredWidth: 400
    Layout.maximumWidth: 400
    implicitHeight: content.implicitHeight + 48
    radius: 14

    readonly property color accentColor: {
        if (!card.notif) return Colors.primary;
        if (card.notif.urgency === NotificationUrgency.Critical) return Colors.error;
        if (card.notif.urgency === NotificationUrgency.Low)
            return Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35);
        return Colors.primary;
    }

    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.92)
    border.color: Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.75)
    border.width: 1.5
    clip: true

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    property bool shown: false
    opacity: shown ? 1.0 : 0.0
    x: shown ? 0 : 40

    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    Behavior on x {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: shown = true

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Item {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignVCenter

            Image {
                anchors.fill: parent
                visible: card.notif && card.notif.image !== ""
                source: card.notif ? card.notif.image : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
            }
            IconImage {
                anchors.fill: parent
                visible: card.notif && card.notif.image === "" && card.notif.appIcon !== ""
                source: card.notif ? card.notif.appIcon : ""
            }
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                visible: card.notif && card.notif.image === "" && card.notif.appIcon === ""
                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    color: Colors.surfaceText
                    font.pixelSize: 22
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: card.notif ? card.notif.summary : ""
                    color: Colors.surfaceText
                    font.pixelSize: 17
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true 
                }

                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 1
                }
            }

            Text {
                visible: card.notif && card.notif.body.length > 0
                text: card.notif ? card.notif.body : ""
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.75)
                font.pixelSize: 14
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    Rectangle {
        id: closeZone
        anchors.top: card.top
        anchors.bottom: card.bottom
        anchors.right: card.right
        width: 56
        color: closeHover.hovered
            ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            anchors.centerIn: parent
            width: 28
            height: 28
            radius: 8
            color: closeHover.hovered
                ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: closeHover.hovered
                    ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.85)
                    : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                font.pixelSize: 14
            }
        }

        HoverHandler { id: closeHover }
        TapHandler {
            onTapped: if (card.notif) NotificationService.dismissByLocalId(card.notif.localId)
        }
    }

    TapHandler {
        enabled: !closeHover.hovered
        onTapped: {
            if (!card.notif) return;
            NotificationService.openSource(card.notif);
            NotificationService.dismissByLocalId(card.notif.localId);
        }
    }
}