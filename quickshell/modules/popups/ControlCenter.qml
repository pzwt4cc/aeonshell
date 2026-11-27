// ControlCenter.qml

import "../"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth

PopupWindow {
    id: popup

    property bool open: false
    property bool _animReady: false
    readonly property bool visualOpen: popup.open && popup._animReady
    readonly property bool isHovered: menuHover.hovered

    function toggle() {
        popup.open = !popup.open;
    }

    readonly property int panelWidth: 460
    readonly property int panelMargin: 24
    readonly property int cardSpacing: 16
    readonly property int shadowMargin: 14

    readonly property var _netKeepAlive: Networking.devices
    readonly property var _btKeepAlive: Bluetooth.defaultAdapter

    readonly property real audioExpandedH: audioListLoader.item ? audioListLoader.item.implicitHeight : 0
    readonly property real wifiExpandedH: wifiListLoader.item ? Math.min(240, wifiListLoader.item.implicitHeight) : 0
    readonly property real btExpandedH: btListLoader.item ? Math.min(280, btListLoader.item.implicitHeight) : 0

    readonly property real targetContentHeight: contentCol.implicitHeight - audioListWrap.height + (popup.audioExpanded ? audioExpandedH : 0) - wifiListWrap.height + (popup.wifiExpanded ? wifiExpandedH : 0) - btListWrap.height + (popup.btExpanded ? btExpandedH : 0)

    implicitWidth: panelWidth + shadowMargin * 2
    implicitHeight: targetContentHeight + panelMargin * 2 + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running

    // --- Audio (Pipewire) ---
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0

    PwObjectTracker {
        objects: popup.sink ? [popup.sink] : []
    }

    property bool volumeDragging: false

    readonly property var audioSinks: {
        let list = [...Pipewire.nodes.values];
        return list.filter(n => n && n.isSink && !n.isStream && n.audio);
    }
    readonly property var audioSources: {
        let list = [...Pipewire.nodes.values];
        return list.filter(n => n && !n.isSink && !n.isStream && n.audio);
    }

    PwObjectTracker {
        objects: popup.audioSinks.concat(popup.audioSources)
    }

    function isNodeDefault(node) {
        if (!node)
            return false;
        if (node.isSink)
            return !!(popup.sink && node.id === popup.sink.id);
        const src = Pipewire.defaultAudioSource;
        return !!(src && node.id === src.id);
    }

    property bool audioExpanded: false

    // --- Networking (Quickshell.Networking) ---
    readonly property var wifiDevice: {
        const devs = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                return devs[i];
        }
        return null;
    }

    readonly property var wiredDevice: {
        const devs = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wired)
                return devs[i];
        }
        return null;
    }

    readonly property bool wifiPowered: Networking.wifiEnabled
    readonly property bool wifiScanning: !!(wifiDevice && wifiDevice.scannerEnabled)

    readonly property var wifiNetworks: {
        if (!popup.wifiExpanded && wifiListWrap.expandProgress === 0)
            return [];
        if (!wifiDevice || !wifiDevice.networks)
            return [];
        const raw = wifiDevice.networks.values;
        const bestByName = Object.create(null);
        for (let i = 0; i < raw.length; i++) {
            const n = raw[i];
            if (!n || !n.name)
                continue;
            const prev = bestByName[n.name];
            if (!prev || n.connected || (!prev.connected && (n.signalStrength || 0) > (prev.signalStrength || 0)))
                bestByName[n.name] = n;
        }
        const arr = Object.values(bestByName);
        arr.sort((a, b) => (b.connected - a.connected) || ((b.signalStrength || 0) - (a.signalStrength || 0)));
        return arr;
    }

    readonly property string wifiConnName: {
        if (!wifiDevice || !wifiDevice.networks)
            return "";
        const nets = wifiDevice.networks.values;
        for (let i = 0; i < nets.length; i++) {
            if (nets[i] && nets[i].connected)
                return nets[i].name || "";
        }
        return "";
    }

    property bool wifiExpanded: false
    property string pendingSsid: ""
    property var connectingNet: null
    property bool wifiShowPassword: false
    property bool wifiConnecting: !!(connectingNet && connectingNet.stateChanging)
    property bool wifiConnectFailed: false

    onPendingSsidChanged: {
        wifiShowPassword = false;
        wifiConnectFailed = false;
    }

    Connections {
        target: popup.connectingNet
        function onConnectedChanged() {
            if (popup.connectingNet && popup.connectingNet.connected) {
                popup.pendingSsid = "";
                popup.wifiConnectFailed = false;
                popup.connectingNet = null;
            }
        }
        function onConnectionFailed(reason) {
            popup.wifiConnectFailed = true;
            if (reason === ConnectionFailReason.NoSecrets && popup.connectingNet) {
                popup.pendingSsid = popup.connectingNet.name;
            }
            popup.connectingNet = null;
        }
    }

    Timer {
        id: wifiScanTimeout
        interval: 6000
        onTriggered: {
            if (popup.wifiDevice)
                popup.wifiDevice.scannerEnabled = false;
        }
    }

    onWifiExpandedChanged: {
        if (wifiExpanded) {
            if (popup.wifiDevice) {
                popup.wifiDevice.scannerEnabled = true;
                wifiScanTimeout.restart();
            }
        } else {
            wifiScanTimeout.stop();
            if (popup.wifiDevice)
                popup.wifiDevice.scannerEnabled = false;
            popup.pendingSsid = "";
        }
    }

    readonly property bool ethConnected: !!(wiredDevice && wiredDevice.connected)
    readonly property bool ethConnecting: !!(wiredDevice && wiredDevice.state === ConnectionState.Connecting)
    readonly property string ethConnName: {
        if (!wiredDevice || !wiredDevice.connected)
            return "";
        if (wiredDevice.network && wiredDevice.network.name)
            return wiredDevice.network.name;
        if (wiredDevice.linkSpeed > 0)
            return "Wired · " + wiredDevice.linkSpeed + " Mbps";
        return wiredDevice.name || "Connected";
    }

    readonly property bool hasNetworkConnection: popup.ethConnected || (popup.wifiPowered && popup.wifiConnName !== "")

    // --- Bluetooth (Quickshell.Bluetooth) ---
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btPowered: !!(btAdapter && btAdapter.enabled)
    readonly property bool btScanning: !!(btAdapter && btAdapter.discovering)
    property bool btExpanded: false

    property var btPendingDevice: null
    property string btPendingAction: ""
    property string btConnectErrorAddr: ""

    readonly property var btPairedDevices: {
        if (!btAdapter || !btAdapter.devices)
            return [];
        const devs = btAdapter.devices.values;
        const out = [];
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i];
            if (d && (d.paired || d.bonded || d.connected))
                out.push(d);
        }
        out.sort((a, b) => (b.connected - a.connected));
        return out;
    }

    readonly property var btDiscoveredDevices: {
        if (!popup.btExpanded && btListWrap.expandProgress === 0)
            return [];
        if (!btAdapter || !btAdapter.devices)
            return [];
        const devs = btAdapter.devices.values;
        const named = [];
        const unnamed = [];
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i];
            if (!d || d.paired || d.bonded || d.connected)
                continue;
            const n = d.name || d.deviceName || "";
            if (n && n !== d.address)
                named.push(d);
            else
                unnamed.push(d);
        }
        return named.concat(unnamed);
    }

    readonly property var btConnectedDevices: {
        const out = [];
        const devs = popup.btPairedDevices;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected)
                out.push(devs[i]);
        }
        return out;
    }

    function startBtScan() {
        if (!popup.btAdapter || !popup.btPowered)
            return;
        popup.btAdapter.discovering = true;
        btScanTimeout.restart();
    }

    Timer {
        id: btScanTimeout
        interval: 15000
        onTriggered: {
            if (popup.btAdapter)
                popup.btAdapter.discovering = false;
        }
    }

    Connections {
        target: popup.btPendingDevice
        function onConnectedChanged() {
            const d = popup.btPendingDevice;
            if (!d)
                return;
            if (d.connected && popup.btPendingAction !== "disconnect") {
                popup.btPendingDevice = null;
                popup.btPendingAction = "";
                popup.btConnectErrorAddr = "";
            } else if (!d.connected && popup.btPendingAction === "disconnect") {
                popup.btPendingDevice = null;
                popup.btPendingAction = "";
            }
        }
        function onPairedChanged() {
            const d = popup.btPendingDevice;
            if (d && d.paired && popup.btPendingAction === "pair") {
                popup.btPendingAction = "connect";
                d.trusted = true;
                d.connect();
            }
        }
        function onStateChanged() {
            const d = popup.btPendingDevice;
            if (!d)
                return;
            if (d.state === BluetoothDeviceState.Disconnected && popup.btPendingAction === "connect" && !d.pairing) {
                popup.btConnectErrorAddr = d.address;
                popup.btPendingDevice = null;
                popup.btPendingAction = "";
            }
        }
    }

    Timer {
        id: btOpTimeout
        interval: 12000
        running: popup.btPendingDevice !== null
        onTriggered: {
            if (popup.btPendingDevice) {
                popup.btConnectErrorAddr = popup.btPendingDevice.address || "";
                popup.btPendingDevice = null;
                popup.btPendingAction = "";
            }
        }
    }

    onBtExpandedChanged: {
        if (btExpanded) {
            startBtScan();
        } else {
            btScanTimeout.stop();
            if (popup.btAdapter && popup.btAdapter.discovering)
                popup.btAdapter.discovering = false;
        }
    }

    Timer {
        id: hideTimer
        interval: 230
        onTriggered: {
            popup.audioExpanded = false;
            popup.wifiExpanded = false;
            popup.btExpanded = false;
            popup.pendingSsid = "";
        }
    }

    property bool menuWasEntered: false

    Timer {
        id: closeDelayTimer
        interval: 450
        onTriggered: {
            popup.open = false;
            menuWasEntered = false;
        }
    }

    Component.onCompleted: Qt.callLater(() => popup._animReady = true)

    onOpenChanged: {
        if (!open) {
            hideTimer.start();
            menuWasEntered = false;
            closeDelayTimer.stop();
            ShellState.suppressVolumeOSD = false;
            if (popup.wifiDevice && popup.wifiDevice.scannerEnabled)
                popup.wifiDevice.scannerEnabled = false;
            if (popup.btAdapter && popup.btAdapter.discovering)
                popup.btAdapter.discovering = false;
        } else {
            hideTimer.stop();
        }
    }

    Rectangle {
        anchors.fill: menuBg
        anchors.margins: -6
        radius: menuBg.radius + 6
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: menuBg.opacity * 0.35
        scale: menuBg.scale
        transformOrigin: menuBg.transformOrigin
        z: menuBg.z - 1
    }

    Rectangle {
        id: menuBg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: AppSettings.barPosition === "bottom" ? undefined : parent.top
        anchors.bottom: AppSettings.barPosition === "bottom" ? parent.bottom : undefined
        anchors.margins: popup.shadowMargin
        height: contentCol.implicitHeight + popup.panelMargin * 2
        radius: 26
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
        border.width: 1
        clip: true

        readonly property bool barVertical: AppSettings.barPosition === "left" || AppSettings.barPosition === "right"
        readonly property int slideDist: 8

        transformOrigin: {
            if (AppSettings.barPosition === "bottom")
                return Item.BottomRight;
            if (AppSettings.barPosition === "left")
                return Item.BottomLeft;
            if (AppSettings.barPosition === "right")
                return Item.BottomRight;
            return Item.TopRight;
        }
        scale: popup.visualOpen ? 1.0 : 0.88
        opacity: popup.visualOpen ? 1.0 : 0.0
        x: menuBg.barVertical ? (popup.visualOpen ? 0 : (AppSettings.barPosition === "right" ? menuBg.slideDist : -menuBg.slideDist)) : 0
        y: menuBg.barVertical ? 0 : (popup.visualOpen ? 0 : (AppSettings.barPosition === "bottom" ? menuBg.slideDist : -menuBg.slideDist))

        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        HoverHandler {
            id: menuHover
            onHoveredChanged: {
                if (menuHover.hovered) {
                    menuWasEntered = true;
                    closeDelayTimer.stop();
                } else if (menuWasEntered && popup.pendingSsid === "") {
                    closeDelayTimer.start();
                }
            }
        }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: popup.panelMargin
            spacing: popup.cardSpacing

            Text {
                text: "Quick Settings"
                color: Colors.surfaceText
                font.pixelSize: 20
                font.bold: true
                Layout.bottomMargin: 2
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: !popup.hasNetworkConnection
                radius: 12
                color: Qt.rgba(1, 0.55, 0.35, 0.15)
                border.color: Qt.rgba(1, 0.55, 0.35, 0.4)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Text {
                        text: "󰀦"
                        color: "#f0a050"
                        font.pixelSize: 15
                    }
                    Text {
                        text: "No network — Wi-Fi and Ethernet are both offline"
                        color: Colors.surfaceText
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // Master Volume Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                radius: 18
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 12
                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)

                        Text {
                            anchors.centerIn: parent
                            text: (popup.muted || popup.volume === 0) ? "󰖁" : "󰕾"
                            font.pixelSize: 20
                            color: Colors.primary
                        }

                        TapHandler {
                            onTapped: {
                                if (popup.sink && popup.sink.audio)
                                    popup.sink.audio.muted = !popup.sink.audio.muted;
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: popup.sink ? (popup.sink.description || popup.sink.nickname || popup.sink.name || "Volume") : "Volume"
                            color: Colors.surfaceText
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Item {
                            id: volSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16

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
                                width: parent.width * Math.min(1, popup.volume)
                                height: 8
                                radius: 4
                                color: Colors.primary
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.min(Math.max(0, parent.width * Math.min(1, popup.volume) - width / 2), parent.width - width)
                                width: (volHover.hovered || popup.volumeDragging) ? 16 : 10
                                height: width
                                radius: width / 2
                                color: "#ffffff"
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }
                            }

                            HoverHandler {
                                id: volHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: false
                                acceptedButtons: Qt.LeftButton

                                function applyVol(mx) {
                                    let v = Math.max(0, Math.min(1, mx / volSlider.width));
                                    if (popup.sink && popup.sink.audio) {
                                        popup.sink.audio.volume = v;
                                        if (v > 0)
                                            popup.sink.audio.muted = false;
                                    }
                                }

                                onPressed: mouse => {
                                    ShellState.suppressVolumeOSD = true;
                                    popup.volumeDragging = true;
                                    applyVol(mouse.x);
                                }
                                onPositionChanged: mouse => {
                                    if (popup.volumeDragging)
                                        applyVol(mouse.x);
                                }
                                onReleased: {
                                    popup.volumeDragging = false;
                                    ShellState.suppressVolumeOSD = false;
                                }
                                onCanceled: {
                                    popup.volumeDragging = false;
                                    ShellState.suppressVolumeOSD = false;
                                }
                            }
                        }
                    }

                    Text {
                        text: Math.round(Math.min(1, popup.volume) * 100) + "%"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                        font.pixelSize: 14
                        font.bold: true
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // Audio Devices Card
            Rectangle {
                id: audioCard
                Layout.fillWidth: true
                Layout.preferredHeight: audioContentCol.implicitHeight + 36
                radius: 18
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                border.width: 1
                clip: true

                ColumnLayout {
                    id: audioContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 10

                    RowLayout {
                        id: audioHeader
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: 12
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                            Text {
                                anchors.centerIn: parent
                                text: "󰍬"
                                font.pixelSize: 18
                                color: Colors.primary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Audio Devices"
                                color: Colors.surfaceText
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                text: {
                                    const outName = popup.sink ? (popup.sink.description || popup.sink.nickname || popup.sink.name || "Unknown") : "None";
                                    const srcNode = Pipewire.defaultAudioSource;
                                    const inName = srcNode ? (srcNode.description || srcNode.nickname || srcNode.name || "Unknown") : "None";
                                    return outName + "  ·  " + inName;
                                }
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 8
                            color: expandHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : "transparent"

                            HoverHandler {
                                id: expandHover
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅀"
                                font.pixelSize: 13
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                                rotation: popup.audioExpanded ? 180 : 0
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: popup.audioExpanded = !popup.audioExpanded
                            }
                        }
                    }

                    Item {
                        id: audioListWrap
                        Layout.fillWidth: true
                        clip: true

                        property real expandProgress: popup.audioExpanded ? 1 : 0
                        Behavior on expandProgress {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }

                        Layout.preferredHeight: expandProgress * popup.audioExpandedH
                        opacity: expandProgress

                        Loader {
                            id: audioListLoader
                            width: parent.width
                            active: popup.audioExpanded || audioListWrap.expandProgress > 0
                            sourceComponent: ColumnLayout {
                                width: audioListWrap.width
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "OUTPUT"
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.leftMargin: 2
                                    }

                                    Text {
                                        visible: popup.audioSinks.length === 0
                                        text: "No output devices found"
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                        font.pixelSize: 13
                                        Layout.leftMargin: 2
                                    }

                                    Repeater {
                                        model: popup.audioSinks
                                        delegate: AudioDeviceRow {
                                            required property var modelData
                                            node: modelData
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "INPUT"
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.leftMargin: 2
                                    }

                                    Text {
                                        visible: popup.audioSources.length === 0
                                        text: "No input devices found"
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                        font.pixelSize: 13
                                        Layout.leftMargin: 2
                                    }

                                    Repeater {
                                        model: popup.audioSources
                                        delegate: AudioDeviceRow {
                                            required property var modelData
                                            node: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Wi-Fi Card
            Rectangle {
                id: wifiCard
                Layout.fillWidth: true
                Layout.preferredHeight: wifiContentCol.implicitHeight + 36
                radius: 18
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                border.width: 1
                clip: true

                ColumnLayout {
                    id: wifiContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 10

                    RowLayout {
                        id: wifiHeader
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: 12
                            color: popup.wifiPowered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                            Text {
                                anchors.centerIn: parent
                                text: "󰖩"
                                font.pixelSize: 18
                                color: popup.wifiPowered ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Wi-Fi"
                                color: Colors.surfaceText
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                text: {
                                    if (!popup.wifiPowered)
                                        return "Off";
                                    if (popup.wifiConnecting)
                                        return "Connecting to " + (popup.connectingNet ? popup.connectingNet.name : popup.pendingSsid) + "…";
                                    if (popup.wifiConnectFailed)
                                        return "Couldn't connect" + (popup.pendingSsid ? " to " + popup.pendingSsid : "");
                                    return popup.wifiConnName || "Not connected";
                                }
                                color: popup.wifiConnectFailed ? Qt.rgba(1, 0.5, 0.5, 0.85) : (popup.wifiConnecting ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5))
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            visible: popup.wifiConnecting
                            text: "󰝲"
                            color: Colors.primary
                            font.pixelSize: 14
                            RotationAnimation on rotation {
                                running: popup.wifiConnecting
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 800
                            }
                        }

                        Text {
                            visible: !popup.wifiConnecting && popup.wifiConnectFailed
                            text: "󰀦"
                            color: "#f0a050"
                            font.pixelSize: 14
                        }

                        ToggleSwitch {
                            checked: popup.wifiPowered
                            onToggled: {
                                Networking.wifiEnabled = !popup.wifiPowered;
                                if (popup.wifiPowered)
                                    popup.wifiExpanded = false;
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 8
                            color: wifiExpandHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : "transparent"

                            HoverHandler {
                                id: wifiExpandHover
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅀"
                                font.pixelSize: 13
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                                rotation: popup.wifiExpanded ? 180 : 0
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: if (popup.wifiPowered)
                                    popup.wifiExpanded = !popup.wifiExpanded
                            }
                        }
                    }

                    ScrollView {
                        id: wifiListWrap
                        Layout.fillWidth: true
                        clip: true

                        property real expandProgress: popup.wifiExpanded ? 1 : 0
                        Behavior on expandProgress {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }

                        Layout.preferredHeight: expandProgress * popup.wifiExpandedH
                        opacity: expandProgress

                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            id: wifiScrollBar
                            policy: ScrollBar.AsNeeded
                            width: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: wifiScrollBar.hovered || wifiScrollBar.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }
                        }

                        Loader {
                            id: wifiListLoader
                            width: wifiListWrap.availableWidth
                            active: popup.wifiExpanded || wifiListWrap.expandProgress > 0
                            sourceComponent: ColumnLayout {
                                width: wifiListWrap.availableWidth
                                spacing: 4

                                Text {
                                    visible: popup.wifiScanning
                                    text: "Scanning for networks…"
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                    font.pixelSize: 13
                                    Layout.leftMargin: 2
                                }

                                Text {
                                    visible: !popup.wifiScanning && popup.wifiNetworks.length === 0
                                    text: "No networks found"
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                    font.pixelSize: 13
                                    Layout.leftMargin: 2
                                }

                                Repeater {
                                    model: popup.wifiNetworks
                                    delegate: NetworkRow {
                                        required property var modelData
                                        network: modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Ethernet Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                radius: 18
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 12
                        color: popup.ethConnected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                        Text {
                            anchors.centerIn: parent
                            text: "󰌗"
                            font.pixelSize: 18
                            color: popup.ethConnected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Ethernet"
                            color: Colors.surfaceText
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Text {
                            text: popup.ethConnected ? popup.ethConnName : (popup.ethConnecting ? "Connecting…" : "Not connected")
                            color: popup.ethConnecting ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        visible: popup.ethConnecting
                        text: "󰝲"
                        color: Colors.primary
                        font.pixelSize: 14
                        RotationAnimation on rotation {
                            running: popup.ethConnecting
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 800
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: ethSettingsHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : "transparent"

                        HoverHandler {
                            id: ethSettingsHover
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            font.pixelSize: 15
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                        }

                        TapHandler {
                            onTapped: Quickshell.execDetached(["nm-connection-editor"])
                        }
                    }
                }
            }

            // Bluetooth Card
            Rectangle {
                id: btCard
                Layout.fillWidth: true
                Layout.preferredHeight: btContentCol.implicitHeight + 36
                radius: 18
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                border.width: 1
                clip: true

                ColumnLayout {
                    id: btContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 10

                    RowLayout {
                        id: btHeader
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: 12
                            color: popup.btPowered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                            Text {
                                anchors.centerIn: parent
                                text: "󰂯"
                                font.pixelSize: 18
                                color: popup.btPowered ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Bluetooth"
                                color: Colors.surfaceText
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                text: {
                                    if (!popup.btPowered)
                                        return "Off";
                                    if (popup.btPendingDevice) {
                                        const name = popup.btPendingDevice.name || popup.btPendingDevice.deviceName || popup.btPendingDevice.address;
                                        const verb = popup.btPendingAction === "disconnect" ? "Disconnecting from " : (popup.btPendingAction === "pair" ? "Pairing " : "Connecting to ");
                                        return verb + name + "…";
                                    }
                                    if (popup.btConnectErrorAddr !== "")
                                        return "Couldn't connect";
                                    const connected = popup.btConnectedDevices;
                                    return connected.length > 0 ? connected.map(d => d.name || d.deviceName || d.address).join(", ") : "Not connected";
                                }
                                color: popup.btConnectErrorAddr !== "" ? Qt.rgba(1, 0.5, 0.5, 0.85) : (popup.btPendingDevice ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5))
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            visible: popup.btPendingDevice !== null
                            text: "󰝲"
                            color: Colors.primary
                            font.pixelSize: 14
                            RotationAnimation on rotation {
                                running: popup.btPendingDevice !== null
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 800
                            }
                        }

                        Text {
                            visible: popup.btPendingDevice === null && popup.btConnectErrorAddr !== ""
                            text: "󰀦"
                            color: "#f0a050"
                            font.pixelSize: 14
                        }

                        ToggleSwitch {
                            checked: popup.btPowered
                            onToggled: {
                                if (!popup.btAdapter)
                                    return;
                                const next = !popup.btPowered;
                                popup.btAdapter.enabled = next;
                                if (!next)
                                    popup.btExpanded = false;
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 8
                            color: btExpandHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : "transparent"

                            HoverHandler {
                                id: btExpandHover
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅀"
                                font.pixelSize: 13
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                                rotation: popup.btExpanded ? 180 : 0
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: if (popup.btPowered)
                                    popup.btExpanded = !popup.btExpanded
                            }
                        }
                    }

                    ScrollView {
                        id: btListWrap
                        Layout.fillWidth: true
                        clip: true

                        property real expandProgress: popup.btExpanded ? 1 : 0
                        Behavior on expandProgress {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }

                        Layout.preferredHeight: expandProgress * popup.btExpandedH
                        opacity: expandProgress

                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            id: btScrollBar
                            policy: ScrollBar.AsNeeded
                            width: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: btScrollBar.hovered || btScrollBar.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }
                        }

                        Loader {
                            id: btListLoader
                            width: btListWrap.availableWidth
                            active: popup.btExpanded || btListWrap.expandProgress > 0
                            sourceComponent: ColumnLayout {
                                width: btListWrap.availableWidth
                                spacing: 4

                                Text {
                                    visible: popup.btPairedDevices.length === 0
                                    text: "No paired devices"
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                    font.pixelSize: 13
                                    Layout.leftMargin: 2
                                }

                                Repeater {
                                    model: popup.btPairedDevices
                                    delegate: BtRow {
                                        required property var modelData
                                        device: modelData
                                        pairedRow: true
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    Layout.topMargin: 4
                                    radius: 10
                                    color: scanRowHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent"

                                    HoverHandler {
                                        id: scanRowHover
                                    }
                                    TapHandler {
                                        onTapped: popup.startBtScan()
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        spacing: 12
                                        Text {
                                            text: "󰜉"
                                            color: Colors.primary
                                            font.pixelSize: 14
                                            RotationAnimation on rotation {
                                                running: popup.btScanning
                                                loops: Animation.Infinite
                                                from: 0
                                                to: 360
                                                duration: 1000
                                            }
                                        }
                                        Text {
                                            text: popup.btScanning ? "Scanning…" : "Scan for devices"
                                            color: Colors.primary
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    visible: popup.btDiscoveredDevices.length > 0
                                    text: "Available devices"
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                    font.pixelSize: 12
                                    Layout.topMargin: 6
                                    Layout.leftMargin: 2
                                }

                                Repeater {
                                    model: popup.btDiscoveredDevices
                                    delegate: BtRow {
                                        required property var modelData
                                        device: modelData
                                        pairedRow: false
                                    }
                                }

                                Text {
                                    visible: popup.btDiscoveredDevices.length === 0 && !popup.btScanning
                                    text: "No new devices found"
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                    font.pixelSize: 13
                                    Layout.topMargin: 4
                                    Layout.leftMargin: 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component ToggleSwitch: Item {
        id: sw
        property bool checked: false
        signal toggled

        implicitWidth: 46
        implicitHeight: 26
        Layout.preferredWidth: 46
        Layout.preferredHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sw.checked ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: sw.checked ? parent.width - width - 3 : 3
                Behavior on x {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        TapHandler {
            onTapped: sw.toggled()
        }
    }

    component AudioDeviceRow: ColumnLayout {
        id: audioRow
        property var node: null
        readonly property bool isDefault: node ? popup.isNodeDefault(node) : false

        function makeDefault() {
            if (!audioRow.isDefault && audioRow.node) {
                if (audioRow.node.isSink)
                    Pipewire.preferredDefaultAudioSink = audioRow.node;
                else
                    Pipewire.preferredDefaultAudioSource = audioRow.node;
            }
        }

        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 13
                color: audioRow.isDefault ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: audioRow.isDefault ? "󰻃" : "󰄰"
                    font.pixelSize: 12
                    color: audioRow.isDefault ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                }

                TapHandler {
                    onTapped: audioRow.makeDefault()
                }
            }

            Text {
                text: audioRow.node ? (audioRow.node.description || audioRow.node.nickname || audioRow.node.name || "Unknown device") : ""
                color: Colors.surfaceText
                font.pixelSize: 13
                font.bold: audioRow.isDefault
                Layout.fillWidth: true
                elide: Text.ElideRight

                TapHandler {
                    onTapped: audioRow.makeDefault()
                }
            }

            Text {
                text: "󰕾"
                font.pixelSize: 14
                color: (audioRow.node && audioRow.node.audio && audioRow.node.audio.muted) ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                TapHandler {
                    onTapped: {
                        if (audioRow.node && audioRow.node.audio)
                            audioRow.node.audio.muted = !audioRow.node.audio.muted;
                    }
                }
            }
        }

        Item {
            id: devVolSlider
            Layout.fillWidth: true
            Layout.leftMargin: 36
            Layout.preferredHeight: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: 6
                radius: 3
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: parent.width * Math.min(1, (audioRow.node && audioRow.node.audio) ? audioRow.node.audio.volume : 0)
                height: 6
                radius: 3
                color: audioRow.isDefault ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                function applyVol(mx) {
                    let v = Math.max(0, Math.min(1, mx / devVolSlider.width));
                    if (audioRow.node && audioRow.node.audio) {
                        audioRow.node.audio.volume = v;
                        if (v > 0)
                            audioRow.node.audio.muted = false;
                    }
                }

                onPressed: mouse => {
                    if (audioRow.isDefault)
                        ShellState.suppressVolumeOSD = true;
                    applyVol(mouse.x);
                }
                onPositionChanged: mouse => applyVol(mouse.x)
                onReleased: ShellState.suppressVolumeOSD = false
                onCanceled: ShellState.suppressVolumeOSD = false
            }
        }
    }

    component NetworkRow: ColumnLayout {
        id: netRow
        property var network: null
        readonly property string ssid: network ? (network.name || "") : ""
        readonly property real rawStrength: network ? (network.signalStrength || 0) : 0
        readonly property real normStrength: rawStrength > 1.0 ? Math.min(1.0, rawStrength / 100.0) : Math.max(0.0, rawStrength)
        readonly property bool isSecured: !!(network && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown)
        readonly property bool active: !!(network && network.connected)

        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 10
            color: netRowHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }

            HoverHandler {
                id: netRowHover
            }
            TapHandler {
                onTapped: {
                    if (!netRow.network || netRow.active)
                        return;
                    if (!netRow.isSecured || netRow.network.known) {
                        popup.wifiConnectFailed = false;
                        popup.connectingNet = netRow.network;
                        netRow.network.connect();
                    } else {
                        popup.pendingSsid = (popup.pendingSsid === netRow.ssid) ? "" : netRow.ssid;
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 12

                Text {
                    text: "󰖩"
                    font.pixelSize: 15
                    color: Colors.surfaceText
                    opacity: 0.35 + 0.65 * netRow.normStrength
                }

                Text {
                    text: netRow.ssid
                    color: Colors.surfaceText
                    font.pixelSize: 14
                    font.bold: netRow.active
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: netRow.isSecured
                    text: "󰌾"
                    font.pixelSize: 12
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                }

                Text {
                    visible: netRow.active
                    text: "󰄬"
                    font.pixelSize: 14
                    color: Colors.primary
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.topMargin: 4
            Layout.bottomMargin: 8
            visible: popup.pendingSsid === netRow.ssid && netRow.ssid !== ""
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 10
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                    border.color: passField.activeFocus ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5) : (popup.wifiConnectFailed ? Qt.rgba(1, 0.4, 0.4, 0.5) : "transparent")
                    border.width: 1
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    TextField {
                        id: passField
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 44
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: popup.wifiShowPassword ? TextInput.Normal : TextInput.Password
                        placeholderText: "Enter network password"
                        placeholderTextColor: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                        font.pixelSize: 14
                        color: Colors.surfaceText
                        background: Item {}
                        selectByMouse: true
                        onAccepted: connectGlyph.doConnect()
                        onTextChanged: popup.wifiConnectFailed = false

                        Connections {
                            target: popup
                            function onPendingSsidChanged() {
                                if (popup.pendingSsid === netRow.ssid && netRow.ssid !== "")
                                    Qt.callLater(() => passField.forceActiveFocus());
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: popup.wifiShowPassword ? "󰈉" : "󰈈"
                        font.pixelSize: 14
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                        TapHandler {
                            onTapped: popup.wifiShowPassword = !popup.wifiShowPassword
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 10
                    color: connectBtnHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    HoverHandler {
                        id: connectBtnHover
                    }

                    Text {
                        id: connectGlyph
                        anchors.centerIn: parent
                        text: popup.wifiConnecting ? "󰝲" : "󰄬"
                        color: Colors.primary
                        font.pixelSize: 16

                        RotationAnimation on rotation {
                            running: popup.wifiConnecting
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 800
                        }

                        function doConnect() {
                            if (!netRow.network || passField.text.length === 0)
                                return;
                            popup.wifiConnectFailed = false;
                            popup.connectingNet = netRow.network;
                            netRow.network.connectWithPsk(passField.text);
                        }
                    }
                    TapHandler {
                        onTapped: connectGlyph.doConnect()
                    }
                }

                Text {
                    text: "󰅖"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    font.pixelSize: 14
                    TapHandler {
                        onTapped: popup.pendingSsid = ""
                    }
                }
            }

            Text {
                visible: popup.wifiConnectFailed
                text: "Failed to connect, check password"
                color: Qt.rgba(1, 0.5, 0.5, 0.85)
                font.pixelSize: 11
                Layout.leftMargin: 2
            }
        }
    }

    component BtRow: Rectangle {
        id: btRow
        property var device: null
        property bool pairedRow: true
        readonly property string addr: device ? (device.address || "") : ""
        readonly property string devName: device ? (device.name || device.deviceName || addr) : ""
        readonly property bool connected: !!(device && device.connected)
        readonly property bool isBusy: (popup.btPendingDevice && popup.btPendingDevice === device) || !!(device && (device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting))
        readonly property bool hasError: popup.btConnectErrorAddr !== "" && popup.btConnectErrorAddr === addr

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 10
        color: btRowHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        HoverHandler {
            id: btRowHover
        }
        TapHandler {
            onTapped: {
                if (!btRow.device || btRow.isBusy)
                    return;
                popup.btConnectErrorAddr = "";
                popup.btPendingDevice = btRow.device;
                if (btRow.pairedRow) {
                    if (btRow.connected) {
                        popup.btPendingAction = "disconnect";
                        btRow.device.disconnect();
                    } else {
                        popup.btPendingAction = "connect";
                        btRow.device.connect();
                    }
                } else {
                    popup.btPendingAction = "pair";
                    btRow.device.trusted = true;
                    btRow.device.pair();
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            Text {
                text: "󰂯"
                font.pixelSize: 14
                color: btRow.connected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
            }

            Text {
                text: btRow.devName
                color: Colors.surfaceText
                font.pixelSize: 14
                font.bold: btRow.connected
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: btRow.isBusy
                text: "󰝲"
                color: Colors.primary
                font.pixelSize: 14
                RotationAnimation on rotation {
                    running: btRow.isBusy
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 800
                }
            }

            Text {
                visible: !btRow.isBusy && btRow.hasError
                text: "󰀦"
                color: "#f0a050"
                font.pixelSize: 13
            }

            Rectangle {
                visible: !btRow.isBusy && !btRow.hasError && btRow.pairedRow && btRow.connected
                width: 94
                height: 24
                radius: 12
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰄬"
                        color: Colors.primary
                        font.pixelSize: 10
                    }
                    Text {
                        text: "Connected"
                        color: Colors.primary
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Rectangle {
                visible: !btRow.isBusy && !btRow.hasError && !btRow.pairedRow
                width: 58
                height: 26
                radius: 13
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Pair"
                    color: Colors.primary
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
