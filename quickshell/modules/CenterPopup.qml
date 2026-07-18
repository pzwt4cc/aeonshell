// CenterPopup.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

PopupWindow {
    id: popup

    property bool open: false
    property string timeText: "00:00:00"
    readonly property bool isHovered: hover.hovered

    readonly property bool trackPlaying: MprisService.isPlaying
    readonly property string trackTitle: MprisService.active ? (MprisService.trackTitle || "Unknown track") : "Nothing playing"
    readonly property string trackArtist: MprisService.active ? (MprisService.trackArtist || "Unknown artist") : "Player inactive"
    readonly property string positionStr: MprisService.positionStr
    readonly property string durationStr: MprisService.durationStr

    property bool seekDragging: false
    property real dragProgress: 0.0
    readonly property real trackProgress: seekDragging ? dragProgress : MprisService.trackProgress

    property bool volumeDragging: false
    property real dragVolume: 0.0
    readonly property real volumeLevel: volumeDragging ? dragVolume : MprisService.volumeLevel
    readonly property int volumePercent: Math.round(volumeLevel * 100)

    readonly property var players: MprisService.playerList
    readonly property string currentPlayer: MprisService.currentPlayer ? MprisService.currentPlayer.dbusName : ""

    readonly property int calendarColW: 270
    readonly property int mediaColW: 270
    readonly property int colSpacing: 24
    readonly property int sideMargins: 20

    readonly property int shadowMargin: 16

    readonly property bool stacked: AppSettings.barPosition === "left" || AppSettings.barPosition === "right"

    readonly property int calendarSectionH: 260
    readonly property int mediaSectionH: 240 + 54

    implicitWidth: stacked
        ? sideMargins * 2 + Math.max(calendarColW, mediaColW) + shadowMargin * 2
        : sideMargins * 2 + calendarColW + 1 + colSpacing * 2 + mediaColW + shadowMargin * 2
    implicitHeight: stacked
        ? sideMargins * 2 + calendarSectionH + colSpacing + 1 + colSpacing + mediaSectionH + shadowMargin * 2
        : 350 + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running

    Timer {
        id: hideTimer
        interval: 150
    }

    onOpenChanged: {
        if (!open) hideTimer.start()
        else hideTimer.stop()
    }

    Rectangle {
        anchors.fill: menuBg
        anchors.margins: -4
        radius: menuBg.radius + 4
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: menuBg.opacity * 0.5
        scale: menuBg.scale
        transformOrigin: menuBg.transformOrigin
        z: menuBg.z - 1
    }

    Rectangle {
        id: menuBg
        anchors.fill: parent
        anchors.margins: popup.shadowMargin
        radius: 24
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.96)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.22)
        border.width: 1
        clip: true

        transformOrigin: {
            if (AppSettings.barPosition === "bottom") return Item.Bottom
            if (AppSettings.barPosition === "left") return Item.Left
            if (AppSettings.barPosition === "right") return Item.Right
            return Item.Top
        }
        scale: popup.open ? 1.0 : 0.8
        opacity: popup.open ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        HoverHandler { id: hover }

        GridLayout {
            anchors.fill: parent
            anchors.margins: popup.sideMargins
            columnSpacing: popup.colSpacing
            rowSpacing: popup.colSpacing
            columns: popup.stacked ? 1 : 3
            rows: popup.stacked ? 3 : 1
            flow: popup.stacked ? GridLayout.TopToBottom : GridLayout.LeftToRight

            ColumnLayout {
                id: calendarCol
                Layout.preferredWidth: popup.calendarColW
                Layout.minimumWidth: popup.calendarColW
                Layout.maximumWidth: popup.stacked ? Infinity : popup.calendarColW
                Layout.fillWidth: popup.stacked
                Layout.fillHeight: !popup.stacked
                Layout.preferredHeight: popup.stacked ? popup.calendarSectionH : -1
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: popup.timeText
                    font.pixelSize: 26
                    font.bold: true
                    color: "#ffffff"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.12)
                    Layout.topMargin: 2
                    Layout.bottomMargin: 4
                }

                DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: grid.locale
                    delegate: Text {
                        text: model.shortName
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.4)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MonthGrid {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: !popup.stacked
                    Layout.preferredHeight: popup.stacked ? 180 : -1
                    locale: Qt.locale()
                    delegate: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: model.day
                        font.pixelSize: 13
                        font.bold: model.today
                        color: model.today ? Colors.primary : (model.month === grid.month ? "#ffffff" : Qt.rgba(1, 1, 1, 0.2))

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.max(parent.width, parent.height) * 0.75
                            height: width
                            radius: width / 2
                            color: Colors.primary
                            opacity: model.today ? 0.25 : 0.0
                            z: -1
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: popup.stacked ? -1 : 1
                Layout.preferredHeight: popup.stacked ? 1 : -1
                Layout.fillWidth: popup.stacked
                Layout.fillHeight: !popup.stacked
                
                gradient: Gradient {
                    orientation: popup.stacked ? Gradient.Horizontal : Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.2; color: Qt.rgba(1, 1, 1, 0.1) }
                    GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.1) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: popup.mediaColW
                Layout.minimumWidth: popup.mediaColW
                Layout.maximumWidth: popup.stacked ? Infinity : popup.mediaColW
                Layout.fillWidth: popup.stacked
                Layout.fillHeight: true
                spacing: 12

                Item { Layout.fillHeight: true }

                ColumnLayout {
                    id: playerSelector
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.topMargin: -4
                    Layout.bottomMargin: 4
                    spacing: 7

                    readonly property string currentLabel: MprisService.identityFor(popup.currentPlayer) || "Unknown source"
                    readonly property int currentIndex: Math.max(0, popup.players.indexOf(popup.currentPlayer))
                    readonly property bool hasMultiplePlayers: popup.players.length > 1

                    function step(delta) {
                        const list = popup.players;
                        if (list.length === 0) return;
                        let idx = list.indexOf(popup.currentPlayer);
                        if (idx === -1) idx = 0;
                        idx = (idx + delta + list.length) % list.length;
                        MprisService.selectPlayer(list[idx]);
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: prevSrcHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : Qt.rgba(255, 255, 255, 0.04)
                            border.color: prevSrcHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3) : "transparent"
                            border.width: 1
                            visible: playerSelector.hasMultiplePlayers
                            
                            scale: prevSrcHover.hovered ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "‹"
                                font.pixelSize: 18
                                font.bold: true
                                color: prevSrcHover.hovered ? Colors.primary : Qt.rgba(1, 1, 1, 0.6)
                            }

                            HoverHandler { id: prevSrcHover }
                            TapHandler { onTapped: playerSelector.step(-1) }
                        }

                        Rectangle {
                            id: sourceCapsule
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 14
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08)
                            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                            border.width: 1

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: playerSelector.currentLabel.toUpperCase()
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1.4
                                color: Qt.rgba(255, 255, 255, 0.9)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: nextSrcHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : Qt.rgba(255, 255, 255, 0.04)
                            border.color: nextSrcHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3) : "transparent"
                            border.width: 1
                            visible: playerSelector.hasMultiplePlayers
                            
                            scale: nextSrcHover.hovered ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "›"
                                font.pixelSize: 18
                                font.bold: true
                                color: nextSrcHover.hovered ? Colors.primary : Qt.rgba(1, 1, 1, 0.6)
                            }

                            HoverHandler { id: nextSrcHover }
                            TapHandler { onTapped: playerSelector.step(1) }
                        }
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 5
                        visible: playerSelector.hasMultiplePlayers

                        Repeater {
                            model: popup.players.length
                            Rectangle {
                                width: index === playerSelector.currentIndex ? 12 : 5
                                height: 5
                                radius: 2.5
                                color: index === playerSelector.currentIndex ? Colors.primary : Qt.rgba(1, 1, 1, 0.2)
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    radius: 16
                    
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(255, 255, 255, 0.03) }
                        GradientStop { position: 1.0; color: Qt.rgba(255, 255, 255, 0.01) }
                    }
                    border.color: Qt.rgba(255, 255, 255, 0.05)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 3
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            Layout.fillWidth: true
                            text: popup.trackTitle
                            color: "#ffffff"
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: popup.trackArtist
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Row {
                    id: visualizer
                    spacing: 5
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 28
                    Layout.topMargin: 4

                    property bool active: popup.trackPlaying

                    Repeater {
                        model: 10
                        Rectangle {
                            id: vBar
                            width: 4
                            radius: 2
                            color: Colors.primary
                            height: 4

                            readonly property int durationUp: [310, 220, 430, 260, 380, 210, 460, 330, 290, 350][index]
                            readonly property int durationDown: [270, 190, 390, 230, 320, 180, 410, 290, 250, 310][index]
                            readonly property int maxH: [20, 26, 18, 28, 22, 27, 19, 24, 21, 25][index]

                            SequentialAnimation {
                                id: anim
                                running: visualizer.active && popup.open
                                loops: Animation.Infinite

                                NumberAnimation { target: vBar; property: "height"; to: vBar.maxH; duration: vBar.durationUp; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: vBar; property: "height"; to: 4; duration: vBar.durationDown; easing.type: Easing.InOutQuad }
                            }

                            Behavior on height {
                                enabled: !anim.running
                                NumberAnimation { duration: 180 }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 28

                    Text {
                        text: "󰒫"
                        font.pixelSize: 20
                        color: btnHoverPrev.hovered ? Colors.primary : "#ffffff"
                        opacity: btnHoverPrev.hovered ? 1.0 : 0.75
                        scale: btnHoverPrev.hovered ? 1.15 : 1.0
                        
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        HoverHandler { id: btnHoverPrev }
                        TapHandler { onTapped: MprisService.previous() }
                    }

                    Rectangle {
                        id: playBtnBg
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: 23
                        
                        color: btnHoverPlay.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : "transparent"
                        border.color: btnHoverPlay.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4) : Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1
                        scale: btnHoverPlay.hovered ? 1.08 : 1.0
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: popup.trackPlaying ? "󰏤" : "󰐊"
                            font.pixelSize: 22
                            color: btnHoverPlay.hovered ? Colors.primary : "#ffffff"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        HoverHandler { id: btnHoverPlay }
                        TapHandler { onTapped: MprisService.playPause() }
                    }

                    Text {
                        text: "󰒬"
                        font.pixelSize: 20
                        color: btnHoverNext.hovered ? Colors.primary : "#ffffff"
                        opacity: btnHoverNext.hovered ? 1.0 : 0.75
                        scale: btnHoverNext.hovered ? 1.15 : 1.0
                        
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        HoverHandler { id: btnHoverNext }
                        TapHandler { onTapped: MprisService.next() }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        id: seekSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: sliderHover.hovered || popup.seekDragging ? 5 : 3
                            radius: 2.5
                            color: Qt.rgba(255, 255, 255, 0.08)
                            Behavior on height { NumberAnimation { duration: 80 } }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            width: parent.width * popup.trackProgress
                            height: sliderHover.hovered || popup.seekDragging ? 5 : 3
                            radius: 2.5
                            color: Colors.primary
                            Behavior on height { NumberAnimation { duration: 80 } }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.min(Math.max(0, parent.width * popup.trackProgress - width/2), parent.width - width)
                            width: sliderHover.hovered || popup.seekDragging ? 10 : 0
                            height: width
                            radius: width / 2
                            color: "#ffffff"
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }

                        HoverHandler { id: sliderHover }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: false
                            acceptedButtons: Qt.LeftButton

                            onPressed: (mouse) => {
                                popup.seekDragging = true;
                                popup.dragProgress = Math.max(0, Math.min(1, mouse.x / seekSlider.width));
                            }
                            onPositionChanged: (mouse) => {
                                if (popup.seekDragging) {
                                    popup.dragProgress = Math.max(0, Math.min(1, mouse.x / seekSlider.width));
                                }
                            }
                            onReleased: {
                                MprisService.seekToFraction(popup.dragProgress);
                                popup.seekDragging = false;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: popup.positionStr
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: popup.durationStr
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: 10
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            id: volumeIcon
                            text: popup.volumeLevel == 0 ? "󰖁" : "󰕾"
                            font.pixelSize: 16
                            color: Qt.rgba(1, 1, 1, 0.55)

                            TapHandler {
                                onTapped: MprisService.toggleMute()
                            }
                        }

                        Item {
                            id: volumeSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: volSliderHover.hovered || popup.volumeDragging ? 5 : 3
                                radius: 2.5
                                color: Qt.rgba(255, 255, 255, 0.08)
                                Behavior on height { NumberAnimation { duration: 80 } }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                width: parent.width * popup.volumeLevel
                                height: volSliderHover.hovered || popup.volumeDragging ? 5 : 3
                                radius: 2.5
                                color: Colors.primary
                                Behavior on height { NumberAnimation { duration: 80 } }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.min(Math.max(0, parent.width * popup.volumeLevel - width/2), parent.width - width)
                                width: volSliderHover.hovered || popup.volumeDragging ? 8 : 0
                                height: width
                                radius: width / 2
                                color: "#ffffff"
                                Behavior on width { NumberAnimation { duration: 80 } }
                            }

                            HoverHandler { id: volSliderHover }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: false
                                acceptedButtons: Qt.LeftButton

                                onPressed: (mouse) => {
                                    popup.volumeDragging = true;
                                    popup.dragVolume = Math.max(0, Math.min(1, mouse.x / volumeSlider.width));
                                    MprisService.setVolume(popup.dragVolume);
                                }
                                onPositionChanged: (mouse) => {
                                    if (popup.volumeDragging) {
                                        popup.dragVolume = Math.max(0, Math.min(1, mouse.x / volumeSlider.width));
                                        MprisService.setVolume(popup.dragVolume);
                                    }
                                }
                                onReleased: { popup.volumeDragging = false; }
                            }
                        }

                        Text {
                            text: popup.volumePercent + "%"
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.pixelSize: 11
                            font.bold: true
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}