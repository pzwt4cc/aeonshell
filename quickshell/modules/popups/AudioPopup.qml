// AudioPopup.qml

import "../"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire

PopupWindow {
    id: popup

    property bool open: false
    property bool _animReady: false
    readonly property bool visualOpen: popup.open && popup._animReady
    property string activeTab: "output" // "output" | "input" | "apps"

    function toggle() {
        popup.open = !popup.open;
    }

    readonly property int panelWidth: 396
    readonly property int panelHeight: 472
    readonly property int shadowMargin: 14

    implicitWidth: panelWidth + shadowMargin * 2
    implicitHeight: panelHeight + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running

    // --- PipeWire State ---
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource
    readonly property var activeMasterNode: popup.activeTab === "input" ? popup.defaultSource : popup.defaultSink
    readonly property bool masterMuted: !!(activeMasterNode && activeMasterNode.audio && activeMasterNode.audio.muted)
    readonly property real masterVol: (activeMasterNode && activeMasterNode.audio) ? activeMasterNode.audio.volume : 0

    readonly property var audioSinks: {
        const list = Pipewire.nodes ? [...Pipewire.nodes.values] : [];
        return list.filter(n => n && n.isSink && !n.isStream && n.audio);
    }
    readonly property var audioSources: {
        const list = Pipewire.nodes ? [...Pipewire.nodes.values] : [];
        return list.filter(n => n && !n.isSink && !n.isStream && n.audio);
    }
    readonly property var audioStreams: {
        const list = Pipewire.nodes ? [...Pipewire.nodes.values] : [];
        return list.filter(n => n && n.isStream && n.audio);
    }

    readonly property var currentListModel: {
        if (popup.activeTab === "input")
            return popup.audioSources;
        if (popup.activeTab === "apps")
            return popup.audioStreams;
        return popup.audioSinks;
    }

    PwObjectTracker {
        objects: {
            const objs = [];
            if (popup.defaultSink)
                objs.push(popup.defaultSink);
            if (popup.defaultSource)
                objs.push(popup.defaultSource);
            return objs.concat(popup.audioSinks, popup.audioSources, popup.audioStreams);
        }
    }

    function nodeLabel(node) {
        if (!node)
            return "Unknown";
        if (node.isStream && node.properties) {
            const app = node.properties["application.name"] || "";
            const media = node.properties["media.name"] || "";
            if (app && media && media !== app)
                return app + " · " + media;
            if (app)
                return app;
        }
        return node.description || node.nickname || node.name || "Audio Device";
    }

    function isNodeDefault(node) {
        if (!node || node.isStream)
            return false;
        if (node.isSink)
            return !!(popup.defaultSink && node.id === popup.defaultSink.id);
        return !!(popup.defaultSource && node.id === popup.defaultSource.id);
    }

    property bool masterDragging: false

    Timer {
        id: hideTimer
        interval: 210
    }

    Component.onCompleted: Qt.callLater(() => popup._animReady = true)

    onOpenChanged: {
        if (open) {
            hideTimer.stop();
        } else {
            hideTimer.start();
            ShellState.suppressVolumeOSD = false;
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: popup.open
        onActivated: popup.open = false
    }

    // Soft ambient shadow
    Rectangle {
        anchors.fill: menuBg
        anchors.margins: -5
        radius: menuBg.radius + 5
        color: Qt.rgba(0, 0, 0, 0.48)
        opacity: menuBg.opacity * 0.35
        scale: menuBg.scale
        transformOrigin: menuBg.transformOrigin
        z: menuBg.z - 1
    }

    Rectangle {
        id: menuBg
        anchors.fill: parent
        anchors.margins: popup.shadowMargin
        radius: 22
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, AppSettings.popupOpacity)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.25)
        border.width: 1
        clip: true

        readonly property bool barVertical: AppSettings.barPosition === "left" || AppSettings.barPosition === "right"
        readonly property int slideDist: 6

        transformOrigin: {
            if (AppSettings.barPosition === "bottom")
                return Item.BottomRight;
            if (AppSettings.barPosition === "left")
                return Item.BottomLeft;
            if (AppSettings.barPosition === "right")
                return Item.BottomRight;
            return Item.TopRight;
        }

        scale: popup.visualOpen ? 1.0 : 0.96
        opacity: popup.visualOpen ? 1.0 : 0.0
        transform: Translate {
            x: menuBg.barVertical ? (popup.visualOpen ? 0 : (AppSettings.barPosition === "right" ? menuBg.slideDist : -menuBg.slideDist)) : 0
            y: menuBg.barVertical ? 0 : (popup.visualOpen ? 0 : (AppSettings.barPosition === "bottom" ? menuBg.slideDist : -menuBg.slideDist))
            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16)
                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.24)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: popup.activeTab === "input" ? "󰍬" : (popup.activeTab === "apps" ? "󰎆" : "󰕾")
                        font.pixelSize: 16
                        color: Colors.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Audio Mixer"
                        color: Colors.surfaceText
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Text {
                        text: popup.activeMasterNode ? popup.nodeLabel(popup.activeMasterNode) : "No active device"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 9
                    color: closeMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.pixelSize: 13
                        color: Colors.surfaceText
                        opacity: closeMa.containsMouse ? 1.0 : 0.6
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.open = false
                    }
                }
            }

            // Master Volume Card (fixed height)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                radius: 15
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 10
                        color: muteMa.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.26) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: popup.activeTab === "input" ? (popup.masterMuted ? "󰍭" : "󰍬") : ((popup.masterMuted || popup.masterVol === 0) ? "󰖁" : "󰕾")
                            font.pixelSize: 18
                            color: Colors.primary
                        }

                        MouseArea {
                            id: muteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popup.activeMasterNode && popup.activeMasterNode.audio)
                                    popup.activeMasterNode.audio.muted = !popup.activeMasterNode.audio.muted;
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: popup.activeTab === "input" ? "Default Input" : "Master Output"
                                color: Colors.surfaceText
                                font.pixelSize: 12
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: popup.masterMuted ? "Muted" : (Math.round(Math.min(1, popup.masterVol) * 100) + "%")
                                color: popup.masterMuted ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45) : Colors.primary
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        Item {
                            id: masterSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 7
                                radius: 4
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12)
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                width: parent.width * Math.min(1, popup.masterMuted ? 0 : popup.masterVol)
                                height: 7
                                radius: 4
                                color: popup.masterMuted ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3) : Colors.primary
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.min(Math.max(0, parent.width * Math.min(1, popup.masterVol) - width / 2), parent.width - width)
                                width: (masterSliderMa.containsMouse || popup.masterDragging) ? 14 : 10
                                height: width
                                radius: width / 2
                                color: "#ffffff"
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }
                            }

                            MouseArea {
                                id: masterSliderMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                function applyVol(mx) {
                                    const v = Math.max(0, Math.min(1, mx / masterSlider.width));
                                    if (popup.activeMasterNode && popup.activeMasterNode.audio) {
                                        popup.activeMasterNode.audio.volume = v;
                                        if (v > 0 && popup.activeMasterNode.audio.muted)
                                            popup.activeMasterNode.audio.muted = false;
                                    }
                                }

                                onPressed: mouse => {
                                    ShellState.suppressVolumeOSD = true;
                                    popup.masterDragging = true;
                                    applyVol(mouse.x);
                                }
                                onPositionChanged: mouse => {
                                    if (popup.masterDragging)
                                        applyVol(mouse.x);
                                }
                                onReleased: {
                                    popup.masterDragging = false;
                                    ShellState.suppressVolumeOSD = false;
                                }
                                onCanceled: {
                                    popup.masterDragging = false;
                                    ShellState.suppressVolumeOSD = false;
                                }
                            }
                        }
                    }
                }
            }

            // Segmented Tabs (Output | Input | Apps)
            Rectangle {
                id: tabBar
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 11
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                border.width: 1

                readonly property int tabIndex: popup.activeTab === "input" ? 1 : (popup.activeTab === "apps" ? 2 : 0)
                readonly property real cellWidth: (width - 6) / 3

                Rectangle {
                    y: 3
                    x: 3 + tabBar.tabIndex * tabBar.cellWidth
                    width: tabBar.cellWidth
                    height: parent.height - 6
                    radius: 8
                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.32)
                    border.width: 1

                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 3

                    AudioTabPill {
                        width: tabBar.cellWidth
                        height: parent.height
                        icon: "󰓃"
                        label: "Output"
                        selected: popup.activeTab === "output"
                        onClicked: popup.activeTab = "output"
                    }
                    AudioTabPill {
                        width: tabBar.cellWidth
                        height: parent.height
                        icon: "󰍬"
                        label: "Input"
                        selected: popup.activeTab === "input"
                        onClicked: popup.activeTab = "input"
                    }
                    AudioTabPill {
                        width: tabBar.cellWidth
                        height: parent.height
                        icon: "󰎆"
                        label: "Apps"
                        selected: popup.activeTab === "apps"
                        onClicked: popup.activeTab = "apps"
                    }
                }
            }

            // Fixed-height Scrollable Device / Stream List
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: deviceList
                    anchors.fill: parent
                    spacing: 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: popup.currentListModel

                    readonly property bool scrollable: contentHeight > height + 1

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        id: audioScrollBar
                        policy: deviceList.scrollable ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        interactive: true
                        width: 5
                        background: Item {}
                        contentItem: Rectangle {
                            implicitWidth: 5
                            radius: 2.5
                            color: audioScrollBar.pressed ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, audioScrollBar.hovered ? 0.45 : 0.24)
                        }
                    }

                    delegate: AudioRow {
                        required property var modelData
                        width: deviceList.width - (deviceList.scrollable ? 10 : 0)
                        node: modelData
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: deviceList.count === 0
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: popup.activeTab === "apps" ? "󰎊" : "󰖁"
                        font.pixelSize: 24
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.28)
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: popup.activeTab === "apps" ? "No active audio streams" : (popup.activeTab === "input" ? "No input devices found" : "No output devices found")
                        font.pixelSize: 12
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                    }
                }
            }
        }
    }

    component AudioTabPill: Item {
        id: atp
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal clicked

        RowLayout {
            anchors.centerIn: parent
            spacing: 5
            Text {
                text: atp.icon
                font.pixelSize: 13
                color: atp.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
            }
            Text {
                text: atp.label
                font.pixelSize: 12
                font.bold: atp.selected
                color: atp.selected ? Colors.primary : Colors.surfaceText
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: atp.clicked()
        }
    }

    component AudioRow: Rectangle {
        id: rowRoot
        property var node: null

        readonly property bool isStream: !!(node && node.isStream)
        readonly property bool isDefault: node ? popup.isNodeDefault(node) : false
        readonly property bool muted: !!(node && node.audio && node.audio.muted)
        readonly property real vol: (node && node.audio) ? node.audio.volume : 0
        readonly property int volPct: Math.round(Math.min(1.5, Math.max(0, vol)) * 100)

        function selectAsDefault() {
            if (!rowRoot.node || rowRoot.isStream || rowRoot.isDefault)
                return;
            if (rowRoot.node.isSink)
                Pipewire.preferredDefaultAudioSink = rowRoot.node;
            else
                Pipewire.preferredDefaultAudioSource = rowRoot.node;
        }

        height: 72
        radius: 13
        color: rowRoot.isDefault ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12) : (rowMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.045))
        border.color: rowRoot.isDefault ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: rowRoot.isStream || rowRoot.isDefault ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: rowRoot.selectAsDefault()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: rowRoot.isStream ? "󰎆" : (rowRoot.isDefault ? "󰻃" : "󰄰")
                    font.pixelSize: 13
                    color: rowRoot.isDefault ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                }

                Text {
                    Layout.fillWidth: true
                    text: popup.nodeLabel(rowRoot.node)
                    color: Colors.surfaceText
                    font.pixelSize: 12
                    font.bold: rowRoot.isDefault
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: rowRoot.isDefault
                    radius: 6
                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                    implicitWidth: defTxt.implicitWidth + 10
                    implicitHeight: 18

                    Text {
                        id: defTxt
                        anchors.centerIn: parent
                        text: "Active"
                        font.pixelSize: 10
                        font.bold: true
                        color: Colors.primary
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 7
                    color: rowMuteMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: rowRoot.muted ? "󰖁" : "󰕾"
                        font.pixelSize: 13
                        color: rowRoot.muted ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4) : Colors.surfaceText
                    }

                    MouseArea {
                        id: rowMuteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rowRoot.node && rowRoot.node.audio)
                                rowRoot.node.audio.muted = !rowRoot.node.audio.muted;
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item {
                    id: rowSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 6
                        radius: 3
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.11)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        width: parent.width * Math.min(1, rowRoot.muted ? 0 : rowRoot.vol)
                        height: 6
                        radius: 3
                        color: rowRoot.muted ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3) : (rowRoot.isDefault ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55))
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        function applyVol(mx) {
                            const v = Math.max(0, Math.min(1, mx / rowSlider.width));
                            if (rowRoot.node && rowRoot.node.audio) {
                                rowRoot.node.audio.volume = v;
                                if (v > 0 && rowRoot.node.audio.muted)
                                    rowRoot.node.audio.muted = false;
                            }
                        }

                        onPressed: mouse => {
                            if (rowRoot.isDefault && !rowRoot.isStream)
                                ShellState.suppressVolumeOSD = true;
                            applyVol(mouse.x);
                        }
                        onPositionChanged: mouse => applyVol(mouse.x)
                        onReleased: ShellState.suppressVolumeOSD = false
                        onCanceled: ShellState.suppressVolumeOSD = false
                    }
                }

                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: rowRoot.muted ? "Mute" : (rowRoot.volPct + "%")
                    font.pixelSize: 11
                    font.bold: true
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
                }
            }
        }
    }
}
