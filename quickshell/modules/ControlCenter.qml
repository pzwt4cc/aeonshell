// ControlCenter.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

PopupWindow {
    id: popup

    property bool open: false
    readonly property bool isHovered: menuHover.hovered

    function toggle() { popup.open = !popup.open }

    readonly property int panelWidth: 460
    readonly property int panelMargin: 24
    readonly property int cardSpacing: 16

    readonly property int shadowMargin: 14

    implicitWidth: panelWidth + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running

    readonly property real audioCardTargetHeight: audioCard.height - audioListWrap.height
        + (popup.audioExpanded ? audioListCol.implicitHeight : 0)
    readonly property real wifiCardTargetHeight: wifiCard.height - wifiListWrap.height
        + (popup.wifiExpanded ? Math.min(240, wifiListCol.implicitHeight) : 0)
    readonly property real btCardTargetHeight: btCard.height - btListWrap.height
        + (popup.btExpanded ? Math.min(280, btListCol.implicitHeight) : 0)

    readonly property real targetContentHeight: contentCol.implicitHeight
        - audioCard.height + audioCardTargetHeight
        - wifiCard.height + wifiCardTargetHeight
        - btCard.height + btCardTargetHeight

    implicitHeight: targetContentHeight + panelMargin * 2 + shadowMargin * 2
    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }


    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0

    PwObjectTracker { objects: popup.sink ? [popup.sink] : [] }

    property bool volumeDragging: false

    readonly property var audioSinks: {
        let list = [...Pipewire.nodes.values];
        return list.filter(function (n) { return n && n.isSink && !n.isStream && n.audio; });
    }
    readonly property var audioSources: {
        let list = [...Pipewire.nodes.values];
        return list.filter(function (n) { return n && !n.isSink && !n.isStream && n.audio; });
    }

    PwObjectTracker { objects: popup.audioSinks.concat(popup.audioSources) }

    function isNodeDefault(node) {
        if (!node) return false;
        if (node.isSink) return !!(popup.sink && node.id === popup.sink.id);
        const src = Pipewire.defaultAudioSource;
        return !!(src && node.id === src.id);
    }

    property bool audioExpanded: false

    property bool wifiPowered: false
    property string wifiConnName: ""
    property bool wifiExpanded: false
    property bool wifiScanning: false
    property int wifiScanTicks: 0
    property string pendingSsid: ""
    property string pendingSecurity: ""

    ListModel { id: wifiNetworksModel }

    function syncListModel(model, arr, keyField) {
        const keys = {}
        for (const it of arr) keys[it[keyField]] = true
        for (let i = model.count - 1; i >= 0; i--) {
            if (!keys[model.get(i)[keyField]]) model.remove(i)
        }
        for (let i = 0; i < arr.length; i++) {
            const item = arr[i]
            let idx = -1
            for (let j = 0; j < model.count; j++) {
                if (model.get(j)[keyField] === item[keyField]) { idx = j; break }
            }
            if (idx === -1) {
                model.insert(i, item)
            } else {
                if (idx !== i) model.move(idx, i, 1)
                model.set(i, item)
            }
        }
    }

    property bool ethConnected: false
    property bool ethConnecting: false
    property string ethConnName: ""

    readonly property bool hasNetworkConnection: popup.ethConnected || (popup.wifiPowered && popup.wifiConnName !== "")

    property bool wifiShowPassword: false
    property bool wifiConnecting: false
    property bool wifiConnectFailed: false

    onPendingSsidChanged: {
        wifiShowPassword = false
        wifiConnecting = false
        wifiConnectFailed = false
    }

    property bool btPowered: false
    property bool btExpanded: false
    property bool btScanning: false
    property int btScanTicks: 0
    property string btConnectingMac: ""
    property string btConnectingAction: ""
    property string btConnectErrorMac: ""

    ListModel { id: btDevicesModel }
    ListModel { id: btDiscoveredModel }

    function btDeviceName(mac) {
        if (!mac) return ""
        for (let i = 0; i < btDevicesModel.count; i++) {
            if (btDevicesModel.get(i).mac === mac) return btDevicesModel.get(i).name
        }
        for (let i = 0; i < btDiscoveredModel.count; i++) {
            if (btDiscoveredModel.get(i).mac === mac) return btDiscoveredModel.get(i).name
        }
        return ""
    }

    function connectedBtDevices() {
        let arr = []
        for (let i = 0; i < btDevicesModel.count; i++) {
            const d = btDevicesModel.get(i)
            if (d.connected) arr.push(d)
        }
        return arr
    }

    function startBtScan() {
        popup.btScanTicks = 0
        popup.btScanning = true
        if (!btScanProc.running) {
            btScanProc.running = true
        } else {
            btDiscoverReader.running = true
        }
    }

    Timer {
        id: hideTimer
        interval: 230
        onTriggered: {
            popup.audioExpanded = false
            popup.wifiExpanded = false
            popup.btExpanded = false
            popup.pendingSsid = ""
        }
    }

    property bool menuWasEntered: false

    Timer {
        id: closeDelayTimer
        interval: 450
        onTriggered: {
            popup.open = false
            menuWasEntered = false
        }
    }

    onOpenChanged: {
        if (!open) {
            hideTimer.start()
            menuWasEntered = false
            closeDelayTimer.stop()
        } else {
            hideTimer.stop()
            wifiStatusReader.running = true
            ethStatusReader.running = true
            btStatusReader.running = true
            btPairedReader.running = true
        }
    }

    Process {
        id: wifiStatusReader
        command: ["bash", "-c",
            "state=$(nmcli radio wifi 2>/dev/null); echo \"${state:-unknown}\"; " +
            "nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-11-wireless' | head -n1 | cut -d: -f2"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                popup.wifiPowered = (lines[0] || "").trim() === "enabled"
                popup.wifiConnName = lines[1] ? lines[1].trim() : ""
            }
        }
    }

    Process { id: wifiToggleProc }

    Process {
        id: wifiScanProc
        command: ["bash", "-c", "nmcli device wifi rescan >/dev/null 2>&1"]
    }

    Timer {
        id: wifiScanPollTimer
        interval: 1000
        repeat: true
        running: popup.wifiScanning
        onTriggered: {
            popup.wifiScanTicks++
            wifiListReader.running = true
            if (popup.wifiScanTicks >= 5) {
                popup.wifiScanning = false
                popup.wifiScanTicks = 0
            }
        }
    }

    Process {
        id: wifiListReader
        command: ["bash", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                const seen = {}
                let arr = []
                for (const line of lines) {
                    const parts = line.split(":")
                    if (parts.length < 3) continue
                    const inUse = parts[0].trim() === "*"
                    const ssid = parts[1]
                    if (!ssid || seen[ssid]) continue
                    seen[ssid] = true
                    const strength = parseInt(parts[2]) || 0
                    const security = parts.slice(3).join(":").trim()
                    arr.push({ ssid: ssid, strength: strength, security: security, active: inUse })
                }
                arr.sort((a, b) => (b.active - a.active) || (b.strength - a.strength))
                popup.syncListModel(wifiNetworksModel, arr, "ssid")
            }
        }
    }

    Process {
        id: wifiConnectProc
        property string lastResult: ""
        stdout: StdioCollector {
            onStreamFinished: wifiConnectProc.lastResult = this.text.trim()
        }
        onRunningChanged: if (!running) {
            popup.wifiConnecting = false
            if (wifiConnectProc.lastResult.indexOf("OK") !== -1) {
                popup.pendingSsid = ""
            } else {
                popup.wifiConnectFailed = true
            }
            wifiStatusReader.running = true
            wifiListReader.running = true
        }
    }

    onWifiExpandedChanged: {
        if (wifiExpanded) {
            wifiListReader.running = true
            popup.wifiScanTicks = 0
            popup.wifiScanning = true
            wifiScanProc.running = true
        } else {
            popup.pendingSsid = ""
        }
    }

    Process {
        id: ethStatusReader
        command: ["bash", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"ethernet\"{print; exit}'; " +
            "echo '---'; " +
            "nmcli -t -f TYPE,STATE,NAME connection show --active 2>/dev/null | grep '^802-3-ethernet' | head -n1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const chunks = this.text.trim().split("---")
                const devLine = (chunks[0] || "").trim()
                const connLine = (chunks[1] || "").trim()
                const devState = devLine.split(":")[2] || ""

                popup.ethConnecting = devState.indexOf("connecting") === 0

                if (connLine) {
                    const parts = connLine.split(":")
                    popup.ethConnected = true
                    popup.ethConnName = parts.slice(2).join(":") || "Connected"
                } else {
                    popup.ethConnected = false
                    popup.ethConnName = ""
                }
            }
        }
    }

    Process {
        id: ethEditorProc
        command: ["nm-connection-editor"]
    }

    Process { id: setDefaultAudioProc }

    Process {
        id: btStatusReader
        command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: popup.btPowered = this.text.trim() === "on"
        }
    }

    Process { id: btToggleProc }

    Process {
        id: btPairedReader
        command: ["bash", "-c", `
paired=$(bluetoothctl paired-devices 2>/dev/null | grep -E '^Device ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
conn_macs=$(bluetoothctl devices Connected 2>/dev/null | grep -E '^Device ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | awk '{print $2}')

if [ -n "$conn_macs" ]; then
    all_to_check=$( (echo "$paired"; bluetoothctl devices Connected 2>/dev/null | grep -E '^Device ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}') | awk '!seen[$2]++' )
else
    all_to_check="$paired"
fi

echo "$all_to_check" | while read -r tag mac rest; do
  [ "$tag" != "Device" ] && continue
  [ -z "$mac" ] && continue
  
  mac=$(echo "$mac" | sed 's/\\x1b\\[[0-9;]*m//g')
  rest=$(echo "$rest" | sed 's/\\x1b\\[[0-9;]*m//g')
  
  if [ -n "$conn_macs" ]; then
      echo "$conn_macs" | grep -qx "$mac" && conn="yes" || conn="no"
  else
      conn=$(bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" && echo yes || echo no)
  fi
  echo "$mac|$rest|$conn"
done
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                let arr = []
                for (const line of lines) {
                    const parts = line.split("|")
                    if (parts.length < 3) continue
                    arr.push({ mac: parts[0], name: parts[1] || parts[0], connected: parts[2] === "yes" })
                }
                arr.sort((a, b) => (b.connected - a.connected))
                popup.syncListModel(btDevicesModel, arr, "mac")

                if (popup.btConnectErrorMac !== "") {
                    const errDevice = arr.find(d => d.mac === popup.btConnectErrorMac)
                    if (errDevice && errDevice.connected) popup.btConnectErrorMac = ""
                }
            }
        }
    }

    Timer {
        id: btScanPollTimer
        interval: 1000
        repeat: true
        running: popup.btScanning
        onTriggered: {
            popup.btScanTicks++
            btDiscoverReader.running = true
            if (popup.btScanTicks >= 15) {
                popup.btScanning = false
                btScanProc.running = false
                popup.btScanTicks = 0
            }
        }
    }

    Process {
        id: btScanProc
        command: ["bash", "-c", "exec bluetoothctl --timeout 16 scan on >/dev/null 2>&1"]
        onRunningChanged: if (!running) {
            btScanStopProc.running = true
            btDiscoverReader.running = true
        }
    }

    Process {
        id: btScanStopProc
        command: ["bluetoothctl", "scan", "off"]
    }

    Process {
        id: btDiscoverReader
        command: ["bash", "-c", `
exclude_macs=$( (bluetoothctl paired-devices 2>/dev/null; bluetoothctl devices Connected 2>/dev/null) | grep -E '^Device ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | awk '{print $2}' )

bluetoothctl devices 2>/dev/null | grep -E '^Device ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | while read -r tag mac rest; do
  [ "$tag" != "Device" ] && continue
  [ -z "$mac" ] && continue
  
  mac=$(echo "$mac" | sed 's/\\x1b\\[[0-9;]*m//g')
  rest=$(echo "$rest" | sed 's/\\x1b\\[[0-9;]*m//g')
  
  if [ -n "$exclude_macs" ]; then
      echo "$exclude_macs" | grep -qx "$mac" && continue
  fi
  echo "$mac|$rest"
done
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                let arr = []
                for (const line of lines) {
                    const parts = line.split("|")
                    if (parts.length < 2) continue
                    arr.push({ mac: parts[0], name: parts[1] || parts[0] })
                }
                
                let named = []
                let unnamed = []
                for (let i = arr.length - 1; i >= 0; i--) {
                    if (arr[i].name && arr[i].name !== arr[i].mac) {
                        named.push(arr[i])
                    } else {
                        unnamed.push(arr[i])
                    }
                }
                arr = named.concat(unnamed)
                
                popup.syncListModel(btDiscoveredModel, arr, "mac")
            }
        }
    }

    Process {
        id: btConnectProc
        property string actionMac: ""
        property string actionOutput: ""
        stdout: StdioCollector {
            onStreamFinished: btConnectProc.actionOutput = this.text
        }
        onRunningChanged: if (!running) {
            popup.btConnectingMac = ""
            const out = btConnectProc.actionOutput
            const isRealFailure = /fail|error/i.test(out) && !/already connected|already exists/i.test(out)
            popup.btConnectErrorMac = isRealFailure ? btConnectProc.actionMac : ""
            btPairedReader.running = true
            btStatusReader.running = true
        }
    }

    Process {
        id: btPairProc
        property string actionMac: ""
        property string actionOutput: ""
        stdout: StdioCollector {
            onStreamFinished: btPairProc.actionOutput = this.text
        }
        onRunningChanged: if (!running) {
            popup.btConnectingMac = ""
            const out = btPairProc.actionOutput
            const isRealFailure = /fail|error/i.test(out) && !/already exists|already connected/i.test(out)
            popup.btConnectErrorMac = isRealFailure ? btPairProc.actionMac : ""
            btPairedReader.running = true
            btDiscoverReader.running = true
        }
    }

    onBtExpandedChanged: {
        if (btExpanded) {
            btPairedReader.running = true
            startBtScan()
        } else {
            popup.btScanning = false
            btScanProc.running = false
        }
    }

    Timer {
        interval: 3000
        running: popup.open
        repeat: true
        onTriggered: {
            wifiStatusReader.running = true
            ethStatusReader.running = true
            btStatusReader.running = true
            if (popup.wifiExpanded && !popup.wifiScanning) wifiListReader.running = true
            if (popup.btExpanded && !popup.btScanning) btPairedReader.running = true
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
        anchors.fill: parent
        anchors.margins: popup.shadowMargin
        radius: 26
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
        border.width: 1
        clip: true

        readonly property bool barVertical: AppSettings.barPosition === "left" || AppSettings.barPosition === "right"
        readonly property int slideDist: 8

        transformOrigin: {
            if (AppSettings.barPosition === "bottom") return Item.BottomRight
            if (AppSettings.barPosition === "left") return Item.BottomLeft
            if (AppSettings.barPosition === "right") return Item.BottomRight
            return Item.TopRight
        }
        scale: popup.open ? 1.0 : 0.88
        opacity: popup.open ? 1.0 : 0.0
        x: menuBg.barVertical ? (popup.open ? 0 : (AppSettings.barPosition === "right" ? menuBg.slideDist : -menuBg.slideDist)) : 0
        y: menuBg.barVertical ? 0 : (popup.open ? 0 : (AppSettings.barPosition === "bottom" ? menuBg.slideDist : -menuBg.slideDist))

        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
        }
        Behavior on x {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }
        Behavior on y {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }

        HoverHandler {
            id: menuHover
            onHoveredChanged: {
                if (menuHover.hovered) {
                    menuWasEntered = true
                    closeDelayTimer.stop()
                } else if (menuWasEntered) {
                    closeDelayTimer.start()
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
                    Text { text: "󰀦"; color: "#f0a050"; font.pixelSize: 15 }
                    Text {
                        text: "No network — Wi-Fi and Ethernet are both offline"
                        color: Colors.surfaceText
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

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
                                if (popup.sink && popup.sink.audio) popup.sink.audio.muted = !popup.sink.audio.muted
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
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }

                            HoverHandler { id: volHover }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: false
                                acceptedButtons: Qt.LeftButton

                                function applyVol(mx) {
                                    let v = Math.max(0, Math.min(1, mx / volSlider.width))
                                    if (popup.sink && popup.sink.audio) {
                                        popup.sink.audio.volume = v
                                        if (v > 0) popup.sink.audio.muted = false
                                    }
                                }

                                onPressed: (mouse) => { popup.volumeDragging = true; applyVol(mouse.x) }
                                onPositionChanged: (mouse) => { if (popup.volumeDragging) applyVol(mouse.x) }
                                onReleased: popup.volumeDragging = false
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
                                    const outName = popup.sink ? (popup.sink.description || popup.sink.nickname || popup.sink.name || "Unknown") : "None"
                                    const srcNode = Pipewire.defaultAudioSource
                                    const inName = srcNode ? (srcNode.description || srcNode.nickname || srcNode.name || "Unknown") : "None"
                                    return outName + "  ·  " + inName
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

                            HoverHandler { id: expandHover }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅀"
                                font.pixelSize: 13
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                                rotation: popup.audioExpanded ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
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
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }

                        Layout.preferredHeight: expandProgress * audioListCol.implicitHeight
                        opacity: expandProgress

                        ColumnLayout {
                            id: audioListCol
                            width: parent.width
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
                                    delegate: AudioDeviceRow { node: modelData }
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
                                    delegate: AudioDeviceRow { node: modelData }
                                }
                            }
                        }
                    }
                }
            }

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
                            color: popup.wifiPowered
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                                : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
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
                                    if (!popup.wifiPowered) return "Off"
                                    if (popup.wifiConnecting) return "Connecting to " + popup.pendingSsid + "…"
                                    if (popup.wifiConnectFailed) return "Couldn't connect to " + popup.pendingSsid
                                    return popup.wifiConnName || "Not connected"
                                }
                                color: popup.wifiConnectFailed
                                    ? Qt.rgba(1, 0.5, 0.5, 0.85)
                                    : (popup.wifiConnecting ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5))
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
                                from: 0; to: 360
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
                                wifiToggleProc.command = ["bash", "-c", "nmcli radio wifi " + (popup.wifiPowered ? "off" : "on")]
                                wifiToggleProc.running = true
                                popup.wifiPowered = !popup.wifiPowered
                                if (!popup.wifiPowered) popup.wifiExpanded = false
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 8
                            color: wifiExpandHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : "transparent"

                            HoverHandler { id: wifiExpandHover }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅀"
                                font.pixelSize: 13
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                                rotation: popup.wifiExpanded ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                            }

                            TapHandler {
                                onTapped: if (popup.wifiPowered) popup.wifiExpanded = !popup.wifiExpanded
                            }
                        }
                    }

                    ScrollView {
                        id: wifiListWrap
                        Layout.fillWidth: true
                        clip: true

                        property real expandProgress: popup.wifiExpanded ? 1 : 0
                        Behavior on expandProgress {
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }

                        Layout.preferredHeight: expandProgress * Math.min(240, wifiListCol.implicitHeight)
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
                                color: wifiScrollBar.hovered || wifiScrollBar.active
                                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                                    : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        ColumnLayout {
                            id: wifiListCol
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
                                visible: !popup.wifiScanning && wifiNetworksModel.count === 0
                                text: "No networks found"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                font.pixelSize: 13
                                Layout.leftMargin: 2
                            }

                            Repeater {
                                model: wifiNetworksModel
                                delegate: NetworkRow {
                                    ssid: model.ssid
                                    signalStrength: model.strength
                                    security: model.security
                                    active: model.active
                                }
                            }
                        }
                    }
                }
            }

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
                        color: popup.ethConnected
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                            : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
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
                            from: 0; to: 360
                            duration: 800
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 8
                        color: ethSettingsHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : "transparent"

                        HoverHandler { id: ethSettingsHover }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            font.pixelSize: 15
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                        }

                        TapHandler { onTapped: ethEditorProc.running = true }
                    }
                }
            }

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
                            color: popup.btPowered
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
                                : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
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
                                    if (!popup.btPowered) return "Off"
                                    if (popup.btConnectingMac !== "") {
                                        const name = popup.btDeviceName(popup.btConnectingMac)
                                        const verb = popup.btConnectingAction === "disconnect" ? "Disconnecting"
                                            : (popup.btConnectingAction === "pair" ? "Pairing" : "Connecting")
                                        return verb + (name ? " " + (popup.btConnectingAction === "disconnect" ? "from " : "to ") + name : "") + "…"
                                    }
                                    if (popup.btConnectErrorMac !== "") {
                                        const name = popup.btDeviceName(popup.btConnectErrorMac)
                                        return "Couldn't connect" + (name ? " to " + name : "")
                                    }
                                    const connected = popup.connectedBtDevices()
                                    return connected.length > 0 ? connected.map(d => d.name).join(", ") : "Not connected"
                                }
                                color: popup.btConnectErrorMac !== ""
                                    ? Qt.rgba(1, 0.5, 0.5, 0.85)
                                    : (popup.btConnectingMac !== "" ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5))
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            visible: popup.btConnectingMac !== ""
                            text: "󰝲"
                            color: Colors.primary
                            font.pixelSize: 14
                            RotationAnimation on rotation {
                                running: popup.btConnectingMac !== ""
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 800
                            }
                        }

                        Text {
                            visible: popup.btConnectingMac === "" && popup.btConnectErrorMac !== ""
                            text: "󰀦"
                            color: "#f0a050"
                            font.pixelSize: 14
                        }

                        ToggleSwitch {
                            checked: popup.btPowered
                            onToggled: {
                                btToggleProc.command = ["bash", "-c", "bluetoothctl power " + (popup.btPowered ? "off" : "on")]
                                btToggleProc.running = true
                                popup.btPowered = !popup.btPowered
                                if (!popup.btPowered) popup.btExpanded = false
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 8
                            color: btExpandHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08) : "transparent"

                            HoverHandler { id: btExpandHover }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅀"
                                font.pixelSize: 13
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                                rotation: popup.btExpanded ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                            }

                            TapHandler {
                                onTapped: if (popup.btPowered) popup.btExpanded = !popup.btExpanded
                            }
                        }
                    }

                    ScrollView {
                        id: btListWrap
                        Layout.fillWidth: true
                        clip: true

                        property real expandProgress: popup.btExpanded ? 1 : 0
                        Behavior on expandProgress {
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }

                        Layout.preferredHeight: expandProgress * Math.min(280, btListCol.implicitHeight)
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
                                color: btScrollBar.hovered || btScrollBar.active
                                    ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                                    : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        ColumnLayout {
                            id: btListCol
                            width: btListWrap.availableWidth
                            spacing: 4

                            Text {
                                visible: btDevicesModel.count === 0
                                text: "No paired devices"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                font.pixelSize: 13
                                Layout.leftMargin: 2
                            }

                            Repeater {
                                model: btDevicesModel
                                delegate: BtRow {
                                    mac: model.mac
                                    devName: model.name
                                    connected: model.connected
                                    pairedRow: true
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                Layout.topMargin: 4
                                radius: 10
                                color: scanRowHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent"

                                HoverHandler { id: scanRowHover }
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
                                            from: 0; to: 360; duration: 1000
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
                                visible: btDiscoveredModel.count > 0
                                text: "Available devices"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                font.pixelSize: 12
                                Layout.topMargin: 6
                                Layout.leftMargin: 2
                            }

                            Repeater {
                                model: btDiscoveredModel
                                delegate: BtRow {
                                    mac: model.mac
                                    devName: model.name
                                    connected: false
                                    pairedRow: false
                                }
                            }

                            Text {
                                visible: btDiscoveredModel.count === 0 && !popup.btScanning
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

    component ToggleSwitch: Item {
        id: sw
        property bool checked: false
        signal toggled()

        implicitWidth: 46
        implicitHeight: 26
        Layout.preferredWidth: 46
        Layout.preferredHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sw.checked ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: sw.checked ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        TapHandler { onTapped: sw.toggled() }
    }

    component AudioDeviceRow: ColumnLayout {
        id: audioRow
        property var node: null
        readonly property bool isDefault: node ? popup.isNodeDefault(node) : false

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
                    onTapped: {
                        if (!audioRow.isDefault && audioRow.node) {
                            setDefaultAudioProc.command = ["bash", "-c", "wpctl set-default " + audioRow.node.id]
                            setDefaultAudioProc.running = true
                        }
                    }
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
                    onTapped: {
                        if (!audioRow.isDefault && audioRow.node) {
                            setDefaultAudioProc.command = ["bash", "-c", "wpctl set-default " + audioRow.node.id]
                            setDefaultAudioProc.running = true
                        }
                    }
                }
            }

            Text {
                text: "󰕾"
                font.pixelSize: 14
                color: (audioRow.node && audioRow.node.audio && audioRow.node.audio.muted)
                    ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                    : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                TapHandler {
                    onTapped: {
                        if (audioRow.node && audioRow.node.audio) audioRow.node.audio.muted = !audioRow.node.audio.muted
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
                    let v = Math.max(0, Math.min(1, mx / devVolSlider.width))
                    if (audioRow.node && audioRow.node.audio) {
                        audioRow.node.audio.volume = v
                        if (v > 0) audioRow.node.audio.muted = false
                    }
                }

                onPressed: (mouse) => applyVol(mouse.x)
                onPositionChanged: (mouse) => applyVol(mouse.x)
            }
        }
    }

    component NetworkRow: ColumnLayout {
        id: netRow
        property string ssid: ""
        property int signalStrength: 0
        property string security: ""
        property bool active: false

        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 10
            color: netRowHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            HoverHandler { id: netRowHover }
            TapHandler {
                onTapped: {
                    if (netRow.active) return
                    if (netRow.security === "") {
                        wifiConnectProc.command = ["bash", "-c",
                            'nmcli connection up "$1" >/dev/null 2>&1 || nmcli device wifi connect "$1" >/dev/null 2>&1',
                            "bash", netRow.ssid]
                        wifiConnectProc.running = true
                    } else {
                        popup.pendingSsid = (popup.pendingSsid === netRow.ssid) ? "" : netRow.ssid
                        popup.pendingSecurity = netRow.security
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
                    opacity: 0.35 + 0.65 * Math.min(1, netRow.signalStrength / 100)
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
                    visible: netRow.security !== ""
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
            visible: popup.pendingSsid === netRow.ssid
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 10
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                    border.color: passField.activeFocus
                        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                        : (popup.wifiConnectFailed ? Qt.rgba(1, 0.4, 0.4, 0.5) : "transparent")
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }

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

                        Component.onCompleted: forceActiveFocus()
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: popup.wifiShowPassword ? "󰈉" : "󰈈"
                        font.pixelSize: 14
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                        TapHandler { onTapped: popup.wifiShowPassword = !popup.wifiShowPassword }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 10
                    color: connectBtnHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: connectBtnHover }

                    Text {
                        id: connectGlyph
                        anchors.centerIn: parent
                        text: popup.wifiConnecting ? "󰝲" : "󰄬"
                        color: Colors.primary
                        font.pixelSize: 16

                        RotationAnimation on rotation {
                            running: popup.wifiConnecting
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: 800
                        }

                        function doConnect() {
                            if (passField.text.length === 0) return
                            popup.wifiConnecting = true
                            popup.wifiConnectFailed = false
                            wifiConnectProc.command = ["bash", "-c",
                                'nmcli device wifi connect "$1" password "$2" 2>&1 | grep -q "successfully activated" && echo OK || echo FAIL',
                                "bash", netRow.ssid, passField.text]
                            wifiConnectProc.running = true
                        }
                    }
                    TapHandler { onTapped: connectGlyph.doConnect() }
                }

                Text {
                    text: "󰅖"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    font.pixelSize: 14
                    TapHandler { onTapped: popup.pendingSsid = "" }
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
        property string mac: ""
        property string devName: ""
        property bool connected: false
        property bool pairedRow: true
        readonly property bool isBusy: popup.btConnectingMac === btRow.mac
        readonly property bool hasError: popup.btConnectErrorMac === btRow.mac

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 10
        color: btRowHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        HoverHandler { id: btRowHover }
        TapHandler {
            onTapped: {
                if (btConnectProc.running || btPairProc.running) return
                popup.btConnectErrorMac = ""
                popup.btConnectingMac = btRow.mac
                if (btRow.pairedRow) {
                    popup.btConnectingAction = btRow.connected ? "disconnect" : "connect"
                    btConnectProc.actionMac = btRow.mac
                    btConnectProc.command = ["bash", "-c",
                        'bluetoothctl "$2" "$1" 2>&1',
                        "bash", btRow.mac, btRow.connected ? "disconnect" : "connect"]
                    btConnectProc.running = true
                } else {
                    popup.btConnectingAction = "pair"
                    btPairProc.actionMac = btRow.mac
                    btPairProc.command = ["bash", "-c", `
                    mac="$1"
                    bluetoothctl pair "$mac" 2>&1
                    bluetoothctl trust "$mac" 2>&1
                    bluetoothctl connect "$mac" 2>&1
                    `, "bash", btRow.mac]
                    btPairProc.running = true
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
                    from: 0; to: 360
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