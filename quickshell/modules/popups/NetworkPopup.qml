// NetworkPopup.qml

import "../"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

pragma ComponentBehavior: Bound

PopupWindow {
    id: popup

    property bool open: false
    property bool _animReady: false
    readonly property bool visualOpen: popup.open && popup._animReady
    property string activeTab: "wifi" // "wifi" | "bluetooth" | "ethernet"

    function toggle() {
        popup.open = !popup.open;
    }

    readonly property int panelWidth: 408
    readonly property int panelHeight: 472
    readonly property int shadowMargin: 14

    implicitWidth: panelWidth + shadowMargin * 2
    implicitHeight: panelHeight + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running

    readonly property var _netKeepAlive: Networking.devices
    readonly property var _btKeepAlive: Bluetooth.defaultAdapter

    // --- Wi-Fi & Ethernet (Quickshell.Networking) ---
    readonly property var wifiDevice: {
        const devs = popup._netKeepAlive ? popup._netKeepAlive.values : [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                return devs[i];
        }
        return null;
    }

    readonly property var wiredDevice: {
        const devs = popup._netKeepAlive ? popup._netKeepAlive.values : [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wired)
                return devs[i];
        }
        return null;
    }

    readonly property bool wifiPowered: Networking.wifiEnabled
    readonly property bool wifiScanning: !!(wifiDevice && wifiDevice.scannerEnabled)

    readonly property var wifiNetworks: {
        if (!popup.open && !hideTimer.running)
            return [];
        if (!popup.wifiPowered || !wifiDevice || !wifiDevice.networks)
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

    property string pendingSsid: ""
    property var pendingNetwork: null
    property var connectingNet: null
    property bool wifiShowPassword: false
    property bool wifiConnecting: !!(connectingNet && connectingNet.stateChanging)
    property bool wifiConnectFailed: false

    onPendingSsidChanged: {
        wifiShowPassword = false;
        wifiConnectFailed = false;
    }

    function startWifiScan() {
        if (!popup.wifiDevice || !popup.wifiPowered)
            return;
        popup.wifiDevice.scannerEnabled = true;
        wifiScanTimeout.restart();
    }

    Timer {
        id: wifiScanTimeout
        interval: 6000
        onTriggered: {
            if (popup.wifiDevice)
                popup.wifiDevice.scannerEnabled = false;
        }
    }

    Connections {
        target: popup.connectingNet
        function onConnectedChanged() {
            if (popup.connectingNet && popup.connectingNet.connected) {
                popup.pendingSsid = "";
                popup.pendingNetwork = null;
                popup.wifiConnectFailed = false;
                popup.connectingNet = null;
            }
        }
        function onConnectionFailed(reason) {
            popup.wifiConnectFailed = true;
            if (reason === ConnectionFailReason.NoSecrets && popup.connectingNet) {
                popup.pendingNetwork = popup.connectingNet;
                popup.pendingSsid = popup.connectingNet.name || "";
            }
            popup.connectingNet = null;
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
        if (!popup.open && !hideTimer.running)
            return [];
        if (!popup.btPowered || !btAdapter || !btAdapter.devices)
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

    readonly property var btListEntries: {
        if (!popup.btPowered)
            return [];
        const entries = [];
        const paired = popup.btPairedDevices;
        const disc = popup.btDiscoveredDevices;
        if (paired.length > 0) {
            entries.push({
                kind: "header",
                title: "PAIRED DEVICES"
            });
            for (let i = 0; i < paired.length; i++)
                entries.push({
                    kind: "device",
                    device: paired[i],
                    paired: true
                });
        }
        if (disc.length > 0) {
            entries.push({
                kind: "header",
                title: "AVAILABLE DEVICES"
            });
            for (let j = 0; j < disc.length; j++)
                entries.push({
                    kind: "device",
                    device: disc[j],
                    paired: false
                });
        }
        return entries;
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

    Timer {
        id: hideTimer
        interval: 210
        onTriggered: {
            popup.pendingSsid = "";
            popup.pendingNetwork = null;
        }
    }

    Component.onCompleted: Qt.callLater(() => popup._animReady = true)

    function _syncScanners() {
        if (!popup.open) {
            wifiScanTimeout.stop();
            btScanTimeout.stop();
            if (popup.wifiDevice && popup.wifiDevice.scannerEnabled)
                popup.wifiDevice.scannerEnabled = false;
            if (popup.btAdapter && popup.btAdapter.discovering)
                popup.btAdapter.discovering = false;
            return;
        }
        if (popup.activeTab === "wifi") {
            if (popup.btAdapter && popup.btAdapter.discovering)
                popup.btAdapter.discovering = false;
            popup.startWifiScan();
        } else if (popup.activeTab === "bluetooth") {
            if (popup.wifiDevice && popup.wifiDevice.scannerEnabled)
                popup.wifiDevice.scannerEnabled = false;
            popup.startBtScan();
        } else {
            if (popup.wifiDevice && popup.wifiDevice.scannerEnabled)
                popup.wifiDevice.scannerEnabled = false;
            if (popup.btAdapter && popup.btAdapter.discovering)
                popup.btAdapter.discovering = false;
        }
    }

    onOpenChanged: {
        if (open) {
            hideTimer.stop();
            _syncScanners();
        } else {
            hideTimer.start();
            _syncScanners();
        }
    }

    onActiveTabChanged: _syncScanners()

    Shortcut {
        sequence: "Escape"
        enabled: popup.open
        onActivated: {
            if (popup.pendingSsid !== "") {
                popup.pendingSsid = "";
                popup.pendingNetwork = null;
            } else {
                popup.open = false;
            }
        }
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
                        text: popup.activeTab === "bluetooth" ? "󰂯" : (popup.activeTab === "ethernet" ? "󰌗" : "󰖩")
                        font.pixelSize: 16
                        color: Colors.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Network & Bluetooth"
                        color: Colors.surfaceText
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Text {
                        text: {
                            if (popup.ethConnected)
                                return "Ethernet: " + popup.ethConnName;
                            if (popup.wifiPowered && popup.wifiConnName !== "")
                                return "Wi-Fi: " + popup.wifiConnName;
                            if (popup.btConnectedDevices.length > 0)
                                return "BT: " + popup.btConnectedDevices.map(d => d.name || d.deviceName || d.address).join(", ");
                            return "Offline";
                        }
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

            // Segmented Tabs (Wi-Fi | Bluetooth | Ethernet)
            Rectangle {
                id: tabBar
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 11
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                border.width: 1

                readonly property int tabIndex: popup.activeTab === "bluetooth" ? 1 : (popup.activeTab === "ethernet" ? 2 : 0)
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

                    NetTabPill {
                        width: tabBar.cellWidth
                        height: parent.height
                        icon: "󰖩"
                        label: "Wi-Fi"
                        selected: popup.activeTab === "wifi"
                        onClicked: popup.activeTab = "wifi"
                    }
                    NetTabPill {
                        width: tabBar.cellWidth
                        height: parent.height
                        icon: "󰂯"
                        label: "Bluetooth"
                        selected: popup.activeTab === "bluetooth"
                        onClicked: popup.activeTab = "bluetooth"
                    }
                    NetTabPill {
                        width: tabBar.cellWidth
                        height: parent.height
                        icon: "󰌗"
                        label: "Ethernet"
                        selected: popup.activeTab === "ethernet"
                        onClicked: popup.activeTab = "ethernet"
                    }
                }
            }

            // Tab Content Container (fixed size, smooth cross-fade)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ---------------- Wi-Fi View ----------------
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    visible: popup.activeTab === "wifi"

                    // Wi-Fi control bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: 13
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: "Wireless Radio"
                                    color: Colors.surfaceText
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: {
                                        if (!popup.wifiPowered)
                                            return "Turned off";
                                        if (popup.wifiConnecting)
                                            return "Connecting to " + (popup.connectingNet ? popup.connectingNet.name : popup.pendingSsid) + "…";
                                        if (popup.wifiConnectFailed)
                                            return "Connection failed";
                                        return popup.wifiConnName || (popup.wifiScanning ? "Scanning…" : "Not connected");
                                    }
                                    color: popup.wifiConnectFailed ? "#e07070" : (popup.wifiConnecting ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52))
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                visible: popup.wifiPowered
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 8
                                color: wifiScanMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰜉"
                                    font.pixelSize: 14
                                    color: popup.wifiScanning ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                                    RotationAnimation on rotation {
                                        running: popup.wifiScanning
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 900
                                    }
                                }

                                MouseArea {
                                    id: wifiScanMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popup.startWifiScan()
                                }
                            }

                            ToggleSwitch {
                                checked: popup.wifiPowered
                                onToggled: {
                                    Networking.wifiEnabled = !popup.wifiPowered;
                                    if (popup.wifiPowered) {
                                        popup.pendingSsid = "";
                                        popup.pendingNetwork = null;
                                    }
                                }
                            }
                        }
                    }

                    // Wi-Fi list
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: wifiList
                            anchors.fill: parent
                            spacing: 6
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: popup.wifiNetworks

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
                                policy: ScrollBar.AsNeeded
                                width: 5
                            }

                            delegate: NetworkRow {
                                required property var modelData
                                width: wifiList.width
                                network: modelData
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: wifiList.count === 0
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: popup.wifiPowered ? "󰖩" : "󰤭"
                                font.pixelSize: 24
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.28)
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: popup.wifiPowered ? (popup.wifiScanning ? "Scanning for networks…" : "No Wi-Fi networks found") : "Wi-Fi is turned off"
                                font.pixelSize: 12
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                            }
                        }
                    }

                    // Fixed-bottom inline password bar (never moves popup window!)
                    Rectangle {
                        id: passwordPanel
                        Layout.fillWidth: true
                        readonly property bool shown: popup.wifiPowered && popup.pendingSsid !== ""
                        Layout.preferredHeight: shown ? 74 : 0
                        opacity: shown ? 1.0 : 0.0
                        visible: Layout.preferredHeight > 1
                        clip: true
                        radius: 13
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                        border.color: popup.wifiConnectFailed ? Qt.rgba(1, 0.45, 0.45, 0.5) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                        border.width: 1

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Password for " + popup.pendingSsid
                                    color: popup.wifiConnectFailed ? "#f08080" : Colors.surfaceText
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "󰅖"
                                    font.pixelSize: 12
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            popup.pendingSsid = "";
                                            popup.pendingNetwork = null;
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: 8
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                    border.color: passField.activeFocus ? Colors.primary : "transparent"
                                    border.width: 1

                                    TextField {
                                        id: passField
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 30
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: popup.wifiShowPassword ? TextInput.Normal : TextInput.Password
                                        placeholderText: "Enter password…"
                                        placeholderTextColor: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                                        font.pixelSize: 12
                                        color: Colors.surfaceText
                                        background: Item {}
                                        selectByMouse: true
                                        onAccepted: connectBtn.submitConnect()
                                        onTextChanged: popup.wifiConnectFailed = false

                                        Connections {
                                            target: popup
                                            function onPendingSsidChanged() {
                                                if (popup.pendingSsid !== "") {
                                                    passField.text = "";
                                                    Qt.callLater(() => passField.forceActiveFocus());
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: popup.wifiShowPassword ? "󰈉" : "󰈈"
                                        font.pixelSize: 13
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: popup.wifiShowPassword = !popup.wifiShowPassword
                                        }
                                    }
                                }

                                Rectangle {
                                    id: connectBtn
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 8
                                    color: connectMa.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.28) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)

                                    function submitConnect() {
                                        if (!popup.pendingNetwork || passField.text.length === 0)
                                            return;
                                        popup.wifiConnectFailed = false;
                                        popup.connectingNet = popup.pendingNetwork;
                                        popup.pendingNetwork.connectWithPsk(passField.text);
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: popup.wifiConnecting ? "󰝲" : "󰄬"
                                        font.pixelSize: 14
                                        color: Colors.primary
                                        RotationAnimation on rotation {
                                            running: popup.wifiConnecting
                                            loops: Animation.Infinite
                                            from: 0
                                            to: 360
                                            duration: 800
                                        }
                                    }

                                    MouseArea {
                                        id: connectMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: connectBtn.submitConnect()
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------------- Bluetooth View ----------------
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    visible: popup.activeTab === "bluetooth"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: 13
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: "Bluetooth Adapter"
                                    color: Colors.surfaceText
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: {
                                        if (!popup.btAdapter)
                                            return "No adapter available";
                                        if (!popup.btPowered)
                                            return "Turned off";
                                        if (popup.btPendingDevice) {
                                            const name = popup.btPendingDevice.name || popup.btPendingDevice.deviceName || popup.btPendingDevice.address;
                                            const verb = popup.btPendingAction === "disconnect" ? "Disconnecting " : (popup.btPendingAction === "pair" ? "Pairing " : "Connecting ");
                                            return verb + name + "…";
                                        }
                                        if (popup.btConnectedDevices.length > 0)
                                            return popup.btConnectedDevices.map(d => d.name || d.deviceName || d.address).join(", ");
                                        return popup.btScanning ? "Discovering nearby devices…" : "Ready";
                                    }
                                    color: popup.btPendingDevice ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                visible: popup.btPowered
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 8
                                color: btScanMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰜉"
                                    font.pixelSize: 14
                                    color: popup.btScanning ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                                    RotationAnimation on rotation {
                                        running: popup.btScanning
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 900
                                    }
                                }

                                MouseArea {
                                    id: btScanMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popup.startBtScan()
                                }
                            }

                            ToggleSwitch {
                                enabled: popup.btAdapter !== null
                                checked: popup.btPowered
                                onToggled: {
                                    if (!popup.btAdapter)
                                        return;
                                    popup.btAdapter.enabled = !popup.btPowered;
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: btList
                            anchors.fill: parent
                            spacing: 6
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: popup.btListEntries

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
                                policy: ScrollBar.AsNeeded
                                width: 5
                            }

                            delegate: Item {
                                id: btEntry
                                required property var modelData
                                width: btList.width
                                height: btEntry.modelData.kind === "header" ? 20 : 48

                                Text {
                                    visible: btEntry.modelData.kind === "header"
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    text: btEntry.modelData.title || ""
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                }

                                BtRow {
                                    visible: btEntry.modelData.kind === "device"
                                    anchors.fill: parent
                                    device: btEntry.modelData.device || null
                                    pairedRow: Boolean(btEntry.modelData.paired)
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: btList.count === 0
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: popup.btPowered ? "󰂯" : "󰂲"
                                font.pixelSize: 24
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.28)
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: popup.btPowered ? (popup.btScanning ? "Searching for Bluetooth devices…" : "No devices found") : "Bluetooth is turned off"
                                font.pixelSize: 12
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                            }
                        }
                    }
                }

                // ---------------- Ethernet View ----------------
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    visible: popup.activeTab === "ethernet"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: 14
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                        border.color: popup.ethConnected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.32) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: 12
                                color: popup.ethConnected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰌗"
                                    font.pixelSize: 20
                                    color: popup.ethConnected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: popup.ethConnected ? "Wired Connected" : (popup.ethConnecting ? "Connecting…" : "Cable Unplugged")
                                    color: Colors.surfaceText
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                                Text {
                                    text: popup.ethConnected ? popup.ethConnName : (popup.wiredDevice ? (popup.wiredDevice.name || "Ethernet adapter") : "No wired interface")
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                visible: popup.ethConnected
                                radius: 7
                                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16)
                                implicitWidth: ethBadgeTxt.implicitWidth + 12
                                implicitHeight: 22

                                Text {
                                    id: ethBadgeTxt
                                    anchors.centerIn: parent
                                    text: "Online"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Colors.primary
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 12
                        color: nmEditorMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.09) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.045)
                        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                text: "󰒓"
                                font.pixelSize: 15
                                color: Colors.primary
                            }
                            Text {
                                text: "Open Network Connection Editor"
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "󰅂"
                                font.pixelSize: 14
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            }
                        }

                        MouseArea {
                            id: nmEditorMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["nm-connection-editor"])
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }

    component NetTabPill: Item {
        id: ntp
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal clicked

        RowLayout {
            anchors.centerIn: parent
            spacing: 5
            Text {
                text: ntp.icon
                font.pixelSize: 13
                color: ntp.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
            }
            Text {
                text: ntp.label
                font.pixelSize: 12
                font.bold: ntp.selected
                color: ntp.selected ? Colors.primary : Colors.surfaceText
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ntp.clicked()
        }
    }

    component ToggleSwitch: Item {
        id: sw
        property bool checked: false
        signal toggled

        implicitWidth: 44
        implicitHeight: 24
        Layout.preferredWidth: 44
        Layout.preferredHeight: 24

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sw.checked ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.16)
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: sw.checked ? parent.width - width - 3 : 3
                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    component NetworkRow: Rectangle {
        id: netRow
        property var network: null
        readonly property string ssid: network ? (network.name || "") : ""
        readonly property real rawStrength: network ? (network.signalStrength || 0) : 0
        readonly property real normStrength: rawStrength > 1.0 ? Math.min(1.0, rawStrength / 100.0) : Math.max(0.0, rawStrength)
        readonly property bool isSecured: !!(network && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown)
        readonly property bool active: !!(network && network.connected)

        height: 46
        radius: 11
        color: netRow.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12) : (netMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04))
        border.color: netRow.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.32) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: "󰖩"
                font.pixelSize: 15
                color: netRow.active ? Colors.primary : Colors.surfaceText
                opacity: netRow.active ? 1.0 : (0.38 + 0.62 * netRow.normStrength)
            }

            Text {
                text: netRow.ssid
                color: Colors.surfaceText
                font.pixelSize: 13
                font.bold: netRow.active
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: netRow.isSecured && !netRow.active
                text: "󰌾"
                font.pixelSize: 12
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
            }

            Rectangle {
                visible: netRow.active
                radius: 6
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                implicitWidth: connBadge.implicitWidth + 10
                implicitHeight: 20

                Text {
                    id: connBadge
                    anchors.centerIn: parent
                    text: "Connected"
                    font.pixelSize: 10
                    font.bold: true
                    color: Colors.primary
                }
            }
        }

        MouseArea {
            id: netMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: netRow.active ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (!netRow.network || netRow.active)
                    return;
                if (!netRow.isSecured || netRow.network.known) {
                    popup.pendingSsid = "";
                    popup.pendingNetwork = null;
                    popup.wifiConnectFailed = false;
                    popup.connectingNet = netRow.network;
                    netRow.network.connect();
                } else {
                    if (popup.pendingSsid === netRow.ssid) {
                        popup.pendingSsid = "";
                        popup.pendingNetwork = null;
                    } else {
                        popup.pendingNetwork = netRow.network;
                        popup.pendingSsid = netRow.ssid;
                    }
                }
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

        radius: 11
        color: btRow.connected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12) : (btMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04))
        border.color: btRow.connected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.32) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: "󰂯"
                font.pixelSize: 14
                color: btRow.connected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
            }

            Text {
                text: btRow.devName
                color: Colors.surfaceText
                font.pixelSize: 13
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
                radius: 6
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                implicitWidth: btConnBadge.implicitWidth + 10
                implicitHeight: 20

                Text {
                    id: btConnBadge
                    anchors.centerIn: parent
                    text: "Connected"
                    color: Colors.primary
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            Rectangle {
                visible: !btRow.isBusy && !btRow.hasError && !btRow.pairedRow
                radius: 6
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14)
                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.28)
                border.width: 1
                implicitWidth: pairBadge.implicitWidth + 12
                implicitHeight: 22

                Text {
                    id: pairBadge
                    anchors.centerIn: parent
                    text: "Pair"
                    color: Colors.primary
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        MouseArea {
            id: btMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
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
    }
}
