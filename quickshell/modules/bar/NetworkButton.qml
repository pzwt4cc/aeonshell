// NetworkButton.qml

import "../"
import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Bluetooth

pragma ComponentBehavior: Bound

Rectangle {
    id: root

    property bool vertical: false
    property bool active: false

    signal clicked
    signal bluetoothRequested

    readonly property var _netKeepAlive: Networking.devices
    readonly property var _btKeepAlive: Bluetooth.defaultAdapter

    readonly property var wifiDevice: {
        const devs = root._netKeepAlive ? root._netKeepAlive.values : [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                return devs[i];
        }
        return null;
    }

    readonly property var wiredDevice: {
        const devs = root._netKeepAlive ? root._netKeepAlive.values : [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wired)
                return devs[i];
        }
        return null;
    }

    readonly property bool ethConnected: !!(wiredDevice && wiredDevice.connected)
    readonly property bool wifiPowered: Networking.wifiEnabled
    readonly property bool wifiConnected: {
        if (!wifiPowered || !wifiDevice || !wifiDevice.networks)
            return false;
        const nets = wifiDevice.networks.values;
        for (let i = 0; i < nets.length; i++) {
            if (nets[i] && nets[i].connected)
                return true;
        }
        return false;
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btPowered: !!(btAdapter && btAdapter.enabled)
    readonly property int btConnectedCount: {
        if (!btPowered || !btAdapter || !btAdapter.devices)
            return 0;
        const devs = btAdapter.devices.values;
        let count = 0;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].connected)
                count++;
        }
        return count;
    }

    readonly property string netGlyph: {
        if (root.ethConnected)
            return "󰌗";
        if (!root.wifiPowered)
            return "󰤭";
        if (root.wifiConnected)
            return "󰖩";
        return "󰤯";
    }

    readonly property bool online: root.ethConnected || root.wifiConnected

    Layout.preferredWidth: root.vertical ? 32 : Math.max(32, iconRow.implicitWidth + 14)
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    radius: 8
    color: root.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2) : (btnMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent")
    border.color: root.active ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : "transparent"
    border.width: 1

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    RowLayout {
        id: iconRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.netGlyph
            font.pixelSize: 15
            color: root.active ? Colors.primary : (root.online ? (btnMa.containsMouse ? Colors.surfaceText : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.85)) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45))
            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Text {
            visible: !root.vertical && root.btConnectedCount > 0
            text: "󰂯"
            font.pixelSize: 13
            color: Colors.primary
        }
    }

    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.bluetoothRequested();
            else
                root.clicked();
        }
    }
}
