// Player.qml

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool vertical: false
    property bool rightSide: true
    readonly property bool active: MprisService.active
    readonly property string trackTitle: MprisService.trackTitle

    readonly property int rotationAngle: root.rightSide ? 90 : -90

    readonly property int vertTitleBudget: 140
    readonly property int vertSpacing: 2

    Text {
        id: titleMetrics
        text: root.trackTitle
        font.pixelSize: 12
        font.bold: true
        visible: false
    }
    readonly property int vertTitleActualWidth: Math.min(root.vertTitleBudget, Math.max(20, Math.ceil(titleMetrics.implicitWidth) + 4))

    readonly property string playerIconGlyph: {
        if (!root.active) return ""
        const lower = MprisService.playerName.toLowerCase()

        if (lower.includes("spotify")) return "󰓇"
        if (lower.includes("mpv"))     return "󰈯"
        if (lower.includes("vlc"))     return "\uf87c"
        if (lower.includes("mpd"))     return "󰋋"

        const browserKeywords = [
            "firefox", "chrome", "chromium", "brave", "edge", "vivaldi",
            "opera", "zen", "tor browser", "waterfox", "thorium", "librewolf",
            "browser", "safari"
        ]
        for (let i = 0; i < browserKeywords.length; i++) {
            if (lower.includes(browserKeywords[i])) return "󰊯"
        }

        return "󰕾"
    }

    Layout.preferredWidth: root.vertical ? 28 : Math.min(playerRow.implicitWidth, 180)
    Layout.preferredHeight: root.vertical
        ? (28 + (root.trackTitle !== "" ? root.vertSpacing + root.vertTitleActualWidth : 0))
        : playerRow.implicitHeight
    Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    visible: root.active

    RowLayout {
        id: playerRow
        anchors.fill: parent
        visible: !root.vertical
        spacing: 6

        Text {
            text: root.playerIconGlyph
            font.pixelSize: 13
            color: Colors.primary
            visible: MprisService.playerName !== ""
        }

        Text {
            text: root.trackTitle
            color: "#ffffff"
            font.pixelSize: 14
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    component TitleLabel: Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.trackTitle !== ""
        implicitWidth: titleLabel.implicitHeight
        implicitHeight: root.vertTitleActualWidth

        Text {
            id: titleLabel
            text: root.trackTitle
            color: "#ffffff"
            font.pixelSize: 12
            font.bold: true
            width: root.vertTitleActualWidth
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            rotation: root.rotationAngle
            anchors.centerIn: parent
        }
    }

    component IconLabel: Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.playerIconGlyph
        font.pixelSize: 15
        color: Colors.primary
    }

    GridLayout {
        anchors.fill: parent
        visible: root.vertical
        rows: -1
        columns: 1
        rowSpacing: root.vertSpacing
        IconLabel { Layout.row: root.rightSide ? 0 : 1 }
        TitleLabel { Layout.row: root.rightSide ? 1 : 0 }
    }
}