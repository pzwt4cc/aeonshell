// BluetoothService.qml

pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool powered: false
    property bool scanning: false
    property int scanTicks: 0
    property string connectingMac: ""
    property string connectingAction: ""
    property string connectErrorMac: ""

    readonly property bool busy: connectProc.running || pairProc.running

    property alias devicesModel: devicesModelImpl
    property alias discoveredModel: discoveredModelImpl

    ListModel {
        id: devicesModelImpl
    }
    ListModel {
        id: discoveredModelImpl
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

    function deviceName(mac) {
        if (!mac)
            return "";
        for (let i = 0; i < devicesModelImpl.count; i++) {
            if (devicesModelImpl.get(i).mac === mac)
                return devicesModelImpl.get(i).name;
        }
        for (let i = 0; i < discoveredModelImpl.count; i++) {
            if (discoveredModelImpl.get(i).mac === mac)
                return discoveredModelImpl.get(i).name;
        }
        return "";
    }

    function connectedDevices() {
        let arr = [];
        for (let i = 0; i < devicesModelImpl.count; i++) {
            const d = devicesModelImpl.get(i);
            if (d.connected)
                arr.push(d);
        }
        return arr;
    }

    function refreshStatus() {
        statusReader.running = true;
    }
    function refreshPaired() {
        pairedReader.running = true;
    }

    function toggle() {
        toggleProc.command = ["bash", "-c", "bluetoothctl power " + (root.powered ? "off" : "on")];
        toggleProc.running = true;
        root.powered = !root.powered;
    }

    function startScan() {
        root.scanTicks = 0;
        root.scanning = true;
        if (!scanProc.running) {
            scanProc.running = true;
        } else {
            discoverReader.running = true;
        }
    }

    function stopScan() {
        root.scanning = false;
        scanProc.running = false;
    }

    function connectOrDisconnect(mac, connected) {
        if (root.busy)
            return;
        root.connectErrorMac = "";
        root.connectingMac = mac;
        root.connectingAction = connected ? "disconnect" : "connect";
        connectProc.actionMac = mac;
        connectProc.command = ["bash", "-c", 'bluetoothctl "$2" "$1" 2>&1', "bash", mac, connected ? "disconnect" : "connect"];
        connectProc.running = true;
    }

    function pair(mac) {
        if (root.busy)
            return;
        root.connectErrorMac = "";
        root.connectingMac = mac;
        root.connectingAction = "pair";
        pairProc.actionMac = mac;
        pairProc.command = ["bash", "-c", `
        mac="$1"
        bluetoothctl pair "$mac" 2>&1
        bluetoothctl trust "$mac" 2>&1
        bluetoothctl connect "$mac" 2>&1
        `, "bash", mac];
        pairProc.running = true;
    }

    Timer {
        id: scanPollTimer
        interval: 1000
        repeat: true
        running: root.scanning
        onTriggered: {
            root.scanTicks++;
            discoverReader.running = true;
            if (root.scanTicks >= 15) {
                root.scanning = false;
                scanProc.running = false;
                root.scanTicks = 0;
            }
        }
    }

    Process {
        id: statusReader
        command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: root.powered = this.text.trim() === "on"
        }
    }

    Process {
        id: toggleProc
    }

    Process {
        id: pairedReader
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
                const lines = this.text.trim().split("\n").filter(l => l.length > 0);
                let arr = [];
                for (const line of lines) {
                    const parts = line.split("|");
                    if (parts.length < 3)
                        continue;
                    arr.push({
                        mac: parts[0],
                        name: parts[1] || parts[0],
                        connected: parts[2] === "yes"
                    });
                }
                arr.sort((a, b) => (b.connected - a.connected));
                root._syncListModel(devicesModelImpl, arr, "mac");

                if (root.connectErrorMac !== "") {
                    const errDevice = arr.find(d => d.mac === root.connectErrorMac);
                    if (errDevice && errDevice.connected)
                        root.connectErrorMac = "";
                }
            }
        }
    }

    Process {
        id: scanProc
        command: ["bash", "-c", "exec bluetoothctl --timeout 16 scan on >/dev/null 2>&1"]
        onRunningChanged: if (!running) {
            scanStopProc.running = true;
            discoverReader.running = true;
        }
    }

    Process {
        id: scanStopProc
        command: ["bluetoothctl", "scan", "off"]
    }

    Process {
        id: discoverReader
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
                const lines = this.text.trim().split("\n").filter(l => l.length > 0);
                let arr = [];
                for (const line of lines) {
                    const parts = line.split("|");
                    if (parts.length < 2)
                        continue;
                    arr.push({
                        mac: parts[0],
                        name: parts[1] || parts[0]
                    });
                }

                let named = [];
                let unnamed = [];
                for (let i = arr.length - 1; i >= 0; i--) {
                    if (arr[i].name && arr[i].name !== arr[i].mac) {
                        named.push(arr[i]);
                    } else {
                        unnamed.push(arr[i]);
                    }
                }
                arr = named.concat(unnamed);

                root._syncListModel(discoveredModelImpl, arr, "mac");
            }
        }
    }

    Process {
        id: connectProc
        property string actionMac: ""
        property string actionOutput: ""
        stdout: StdioCollector {
            onStreamFinished: connectProc.actionOutput = this.text
        }
        onRunningChanged: if (!running) {
            root.connectingMac = "";
            const out = connectProc.actionOutput;
            const isRealFailure = /fail|error/i.test(out) && !/already connected|already exists/i.test(out);
            root.connectErrorMac = isRealFailure ? connectProc.actionMac : "";
            pairedReader.running = true;
            statusReader.running = true;
        }
    }

    Process {
        id: pairProc
        property string actionMac: ""
        property string actionOutput: ""
        stdout: StdioCollector {
            onStreamFinished: pairProc.actionOutput = this.text
        }
        onRunningChanged: if (!running) {
            root.connectingMac = "";
            const out = pairProc.actionOutput;
            const isRealFailure = /fail|error/i.test(out) && !/already exists|already connected/i.test(out);
            root.connectErrorMac = isRealFailure ? pairProc.actionMac : "";
            pairedReader.running = true;
            discoverReader.running = true;
        }
    }
}
