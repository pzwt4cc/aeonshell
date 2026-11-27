// NotificationCenter.qml

import "../"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

PopupWindow {
    id: popup

    property bool open: false
    property bool _animReady: false
    readonly property bool visualOpen: popup.open && popup._animReady

    function toggle() {
        popup.open = !popup.open;
    }

    readonly property int shadowMargin: 16

    readonly property int maxVisibleRows: 5
    readonly property real estRowHeight: 92
    readonly property real listCapHeight: maxVisibleRows * estRowHeight - list.spacing

    implicitWidth: 480 + shadowMargin * 2
    implicitHeight: contentCol.implicitHeight + 32 + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running

    Component.onCompleted: {
        Qt.callLater(() => popup._animReady = true);
        if (popup.open)
            NotificationService.markAllRead();
    }

    Timer {
        id: hideTimer
        interval: 150
    }

    function notificationModel() {
        if (!popup.open && !hideTimer.running)
            return [];
        const src = NotificationService.history;
        const withIdx = [];
        for (let i = 0; i < src.length; i++) {
            const item = Object.assign({}, src[i], {
                _origIndex: i
            });
            withIdx.push(item);
        }
        if (!AppSettings.groupNotificationsBySource)
            return withIdx;

        const order = [];
        const groups = {};
        for (const item of withIdx) {
            const key = item.appName || "—";
            if (!groups[key]) {
                groups[key] = [];
                order.push(key);
            }
            groups[key].push(item);
        }
        let out = [];
        for (const key of order)
            out = out.concat(groups[key]);
        return out;
    }

    property bool mouseHasEntered: false

    onOpenChanged: {
        if (open) {
            hideTimer.stop();
            mouseHasEntered = false;
            NotificationService.markAllRead();
        } else {
            hideTimer.start();
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 400
        running: popup.open && popup.mouseHasEntered && !bgHover.hovered
        onTriggered: popup.open = false
    }

    Rectangle {
        anchors.fill: bg
        anchors.margins: -6
        radius: bg.radius + 6
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: bg.opacity * 0.35
        scale: bg.scale
        transformOrigin: bg.transformOrigin
        z: bg.z - 1
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: popup.shadowMargin
        radius: 18
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.95)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
        border.width: 1
        clip: true

        transformOrigin: {
            if (AppSettings.barPosition === "bottom")
                return Item.BottomRight;
            if (AppSettings.barPosition === "left")
                return Item.BottomLeft;
            if (AppSettings.barPosition === "right")
                return Item.BottomRight;
            return Item.TopRight;
        }
        scale: popup.visualOpen ? 1.0 : 0.85
        opacity: popup.visualOpen ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutQuad
            }
        }

        HoverHandler {
            id: bgHover
            onHoveredChanged: {
                if (hovered) {
                    popup.mouseHasEntered = true;
                }
            }
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Notifications"
                        color: Colors.surfaceText
                        font.pixelSize: 18
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Do Not Disturb"
                        color: NotificationService.dnd ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                        font.pixelSize: 16
                        font.bold: NotificationService.dnd
                        Layout.rightMargin: 4
                    }

                    Rectangle {
                        id: dndSwitch
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 2
                        radius: height / 2
                        color: NotificationService.dnd ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.18)
                        border.width: 0

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Rectangle {
                            id: knob
                            width: parent.height - 4
                            height: parent.height - 4
                            radius: height / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: NotificationService.dnd ? parent.width - width - 2 : 2
                            color: "white"

                            Behavior on x {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        TapHandler {
                            onTapped: NotificationService.dnd = !NotificationService.dnd
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        id: groupToggleBtn
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: groupRow.implicitWidth + 24
                        radius: height / 2
                        color: AppSettings.groupNotificationsBySource ? Colors.primary : (groupHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.10) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05))
                        border.width: AppSettings.groupNotificationsBySource ? 0 : 1
                        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                        scale: groupTap.pressed ? 0.96 : 1.0

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutQuad
                            }
                        }

                        RowLayout {
                            id: groupRow
                            anchors.centerIn: parent
                            spacing: 6

                            Item {
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12

                                readonly property color iconColor: AppSettings.groupNotificationsBySource ? "white" : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)

                                Rectangle {
                                    width: 7
                                    height: 7
                                    radius: 2
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    color: "transparent"
                                    border.width: 1.2
                                    border.color: parent.iconColor
                                }
                                Rectangle {
                                    width: 7
                                    height: 7
                                    radius: 2
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    color: parent.iconColor
                                }
                            }

                            Text {
                                text: "Group by app"
                                font.pixelSize: 12
                                font.bold: AppSettings.groupNotificationsBySource
                                color: AppSettings.groupNotificationsBySource ? "white" : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                            }
                        }

                        HoverHandler {
                            id: groupHover
                        }
                        TapHandler {
                            id: groupTap
                            onTapped: AppSettings.groupNotificationsBySource = !AppSettings.groupNotificationsBySource
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, popup.listCapHeight)
                Layout.maximumHeight: popup.listCapHeight
                clip: true
                spacing: 10
                model: popup.notificationModel()

                section.property: AppSettings.groupNotificationsBySource ? "appName" : ""
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    width: list.width
                    height: sectionLabel.implicitHeight + 16
                    Text {
                        id: sectionLabel
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        text: section
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                delegate: Rectangle {
                    id: notifCard
                    required property var modelData
                    readonly property string itemImage: modelData && modelData.image ? modelData.image : ""
                    readonly property string itemAppIcon: modelData && modelData.appIcon ? modelData.appIcon : ""
                    readonly property string itemSummary: modelData && modelData.summary ? modelData.summary : ""
                    readonly property string itemTime: modelData && modelData.time ? modelData.time : ""
                    readonly property string itemBody: modelData && modelData.body ? modelData.body : ""
                    readonly property int itemOrigIndex: modelData && modelData._origIndex !== undefined ? modelData._origIndex : -1

                    width: list.width
                    height: Math.max(cardContent.implicitHeight + 28, 76)
                    radius: 14
                    color: cardHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04)

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    HoverHandler {
                        id: cardHover
                    }

                    TapHandler {
                        enabled: !closeHover.hovered
                        onTapped: if (notifCard.modelData)
                            NotificationService.openSource(notifCard.modelData)
                    }

                    RowLayout {
                        id: cardContent
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        Item {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            Layout.alignment: Qt.AlignVCenter

                            readonly property bool hasValidImg: notifImg.source !== "" && notifImg.status !== Image.Error

                            Image {
                                id: notifImg
                                anchors.fill: parent
                                visible: notifCard.itemImage !== "" && status !== Image.Error
                                source: notifCard.itemImage
                                sourceSize: Qt.size(112, 112)
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                            }
                            IconImage {
                                anchors.fill: parent
                                visible: !parent.hasValidImg && notifCard.itemAppIcon !== ""
                                source: notifCard.itemAppIcon
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: Qt.rgba(1, 1, 1, 0.08)
                                visible: !parent.hasValidImg && notifCard.itemAppIcon === ""
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂚"
                                    color: Colors.surfaceText
                                    font.pixelSize: 18
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: notifCard.itemSummary
                                    color: Colors.surfaceText
                                    font.pixelSize: 16
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: notifCard.itemTime
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Rectangle {
                                    id: closeBtn
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 7
                                    color: closeHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 100
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: closeHover.hovered ? Colors.surfaceText : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                        font.pixelSize: 13
                                    }

                                    HoverHandler {
                                        id: closeHover
                                    }
                                    TapHandler {
                                        onTapped: if (notifCard.itemOrigIndex >= 0)
                                            NotificationService.dismissAt(notifCard.itemOrigIndex)
                                    }
                                }
                            }

                            Text {
                                visible: notifCard.itemBody.length > 0
                                text: notifCard.itemBody
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.75)
                                font.pixelSize: 13
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Text {
                visible: NotificationService.history.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 48
                Layout.bottomMargin: 8
                text: "No notifications"
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                font.pixelSize: 18
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: "Clear all"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                    font.pixelSize: 14
                    font.bold: true

                    HoverHandler {
                        id: clearHover
                    }
                    scale: clearHover.hovered ? 1.05 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                        }
                    }

                    TapHandler {
                        onTapped: NotificationService.clearAll()
                    }
                }
            }
        }
    }
}
