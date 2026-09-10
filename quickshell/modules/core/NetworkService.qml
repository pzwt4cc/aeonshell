// NetworkService.qml

pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool wifiPowered: false
    property string wifiConnName: ""
    property bool wifiScanning: false
    property int wifiScanTicks: 0
    property bool wifiConnecting: false
    property bool wifiConnectFailed: false

    property bool ethConnected: false
    property bool ethConnecting: false
    property string ethConnName: ""

    readonly property bool hasConnection: root.ethConnected || (root.wifiPowered && root.wifiConnName !== "")

    property alias networksModel: networksModelImpl
    ListModel {
        id: networksModelImpl
    }

    function _syncListModel(model, arr, keyField) {
        const keys = {};
        for (const it of arr)
            keys[it[keyField]] = true;
        for (let i = model.count - 1; i >= 0; i--) {
            if (!keys[model.get(i)[keyField]])
                model.remove(i);
        }
        for (let i = 0; i < arr.length; i++) {
            const item = arr[i];
            let idx = -1;
            for (let j = 0; j < model.count; j++) {
                if (model.get(j)[keyField] === item[keyField]) {
                    idx = j;
                    break;
                }
            }
            if (idx === -1) {
                model.insert(i, item);
            } else {
                if (idx !== i)
                    model.move(idx, i, 1);
                model.set(i, item);
            }
        }
    }

    signal wifiConnectSucceeded

    function refreshWifiStatus() {
        wifiStatusReader.running = true;
    }
    function refreshEthStatus() {
        ethStatusReader.running = true;
    }
    function refreshWifiList() {
        wifiListReader.running = true;
    }
    function openEthernetEditor() {
        ethEditorProc.running = true;
    }

    function toggleWifi() {
        wifiToggleProc.command = ["bash", "-c", "nmcli radio wifi " + (root.wifiPowered ? "off" : "on")];
        wifiToggleProc.running = true;
        root.wifiPowered = !root.wifiPowered;
    }

    function startWifiScan() {
        root.wifiScanTicks = 0;
        root.wifiScanning = true;
        wifiScanProc.running = true;
    }

    function connectOpen(ssid) {
        wifiConnectProc.command = ["bash", "-c", 'nmcli connection up "$1" >/dev/null 2>&1 || nmcli device wifi connect "$1" >/dev/null 2>&1', "bash", ssid];
        wifiConnectProc.running = true;
    }

    function connectWithPassword(ssid, password) {
        root.wifiConnecting = true;
        root.wifiConnectFailed = false;
        wifiConnectProc.command = ["bash", "-c", 'nmcli device wifi connect "$1" password "$2" 2>&1 | grep -q "successfully activated" && echo OK || echo FAIL', "bash", ssid, password];
        wifiConnectProc.running = true;
    }

    Timer {
        id: wifiScanPollTimer
        interval: 1000
        repeat: true
        running: root.wifiScanning
        onTriggered: {
            root.wifiScanTicks++;
            wifiListReader.running = true;
            if (root.wifiScanTicks >= 5) {
                root.wifiScanning = false;
                root.wifiScanTicks = 0;
            }
        }
    }

    Process {
        id: wifiStatusReader
        command: ["bash", "-c", "state=$(nmcli radio wifi 2>/dev/null); echo \"${state:-unknown}\"; " + "nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-11-wireless' | head -n1 | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                root.wifiPowered = (lines[0] || "").trim() === "enabled";
                root.wifiConnName = lines[1] ? lines[1].trim() : "";
            }
        }
    }

    Process {
        id: wifiToggleProc
    }

    Process {
        id: wifiScanProc
        command: ["bash", "-c", "nmcli device wifi rescan >/dev/null 2>&1"]
    }

    Process {
        id: wifiListReader
        command: ["bash", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0);
                const seen = {};
                let arr = [];
                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts.length < 3)
                        continue;
                    const inUse = parts[0].trim() === "*";
                    const ssid = parts[1];
                    if (!ssid || seen[ssid])
                        continue;
                    seen[ssid] = true;
                    const strength = parseInt(parts[2]) || 0;
                    const security = parts.slice(3).join(":").trim();
                    arr.push({
                        ssid: ssid,
                        strength: strength,
                        security: security,
                        active: inUse
                    });
                }
                arr.sort((a, b) => (b.active - a.active) || (b.strength - a.strength));
                root._syncListModel(networksModelImpl, arr, "ssid");
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
            root.wifiConnecting = false;
            if (wifiConnectProc.lastResult.indexOf("OK") !== -1) {
                root.wifiConnectSucceeded();
            } else {
                root.wifiConnectFailed = true;
            }
            wifiStatusReader.running = true;
            wifiListReader.running = true;
        }
    }

    Process {
        id: ethStatusReader
        command: ["bash", "-c", "nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"ethernet\"{print; exit}'; " + "echo '---'; " + "nmcli -t -f TYPE,STATE,NAME connection show --active 2>/dev/null | grep '^802-3-ethernet' | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const chunks = this.text.trim().split("---");
                const devLine = (chunks[0] || "").trim();
                const connLine = (chunks[1] || "").trim();
                const devState = devLine.split(":")[2] || "";

                root.ethConnecting = devState.indexOf("connecting") === 0;

                if (connLine) {
                    const parts = connLine.split(":");
                    root.ethConnected = true;
                    root.ethConnName = parts.slice(2).join(":") || "Connected";
                } else {
                    root.ethConnected = false;
                    root.ethConnName = "";
                }
            }
        }
    }

    Process {
        id: ethEditorProc
        command: ["nm-connection-editor"]
    }
}
