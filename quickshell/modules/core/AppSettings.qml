// AppSettings.qml

pragma Singleton
import "../"
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    readonly property string confPath: Quickshell.env("HOME") + "/.config/quickshell/settings.conf"

    property string barPosition: "top"
    property bool groupNotificationsBySource: false
    property bool barShowPlayer: true
    property bool barShowTray: true
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string launcherHiddenApps: ""
    property string launcherViewMode: "list"

    property bool edgeToEdge: false

    readonly property int normalGapsIn: 5
    readonly property int normalGapsOut: 10
    readonly property int normalBorderSize: 2
    readonly property int normalRounding: 15

    readonly property int edgeGapsIn: 2
    readonly property int edgeGapsOut: 2

    property var _hiddenSet: ({})

    function _rebuildHiddenSet() {
        const set = Object.create(null);
        if (root.launcherHiddenApps.length > 0) {
            const parts = root.launcherHiddenApps.split(",");
            for (let i = 0; i < parts.length; i++) {
                if (parts[i])
                    set[parts[i]] = true;
            }
        }
        root._hiddenSet = set;
    }

    onLauncherHiddenAppsChanged: root._rebuildHiddenSet()

    function isAppHidden(id) {
        return id ? Boolean(root._hiddenSet[id]) : false;
    }

    function toggleAppHidden(id) {
        if (!id)
            return;
        const list = root.launcherHiddenApps.length ? root.launcherHiddenApps.split(",").filter(Boolean) : [];
        const idx = list.indexOf(id);
        if (idx !== -1)
            list.splice(idx, 1);
        else
            list.push(id);
        root.launcherHiddenApps = list.join(",");
    }

    function _applyGaps() {
        if (!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || Quickshell.env("AEONSHELL_LAUNCHER_ONLY") === "1")
            return;
        const gIn = root.edgeToEdge ? root.edgeGapsIn : root.normalGapsIn;
        const gOut = root.edgeToEdge ? root.edgeGapsOut : root.normalGapsOut;
        const border = root.edgeToEdge ? 0 : root.normalBorderSize;
        const rounding = root.edgeToEdge ? 0 : root.normalRounding;
        if (Hyprland.usingLua) {
            const luaExpr = "hl.config({ general = { gaps_in = " + gIn + ", gaps_out = " + gOut + ", border_size = " + border + " }, decoration = { rounding = " + rounding + " } })";
            gapsProc.command = ["hyprctl", "eval", luaExpr];
            gapsProc.running = true;
        } else {
            gapsProc.command = ["hyprctl", "--batch", "keyword general:gaps_in " + gIn + ";" + "keyword general:gaps_out " + gOut + ";" + "keyword general:border_size " + border + ";" + "keyword decoration:rounding " + rounding];
            gapsProc.running = true;
        }
    }

    onEdgeToEdgeChanged: root._applyGaps()

    Settings {
        id: shellSettings
        category: "Shell"
        location: "file://" + root.confPath

        property alias barPosition: root.barPosition
        property alias groupNotificationsBySource: root.groupNotificationsBySource
        property alias barShowPlayer: root.barShowPlayer
        property alias barShowTray: root.barShowTray
        property alias wallpaperDir: root.wallpaperDir
        property alias launcherHiddenApps: root.launcherHiddenApps
        property alias launcherViewMode: root.launcherViewMode
        property alias edgeToEdge: root.edgeToEdge
    }

    Process {
        id: gapsProc
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" || event.name === "monitoradded" || event.name === "monitorremoved") {
                root._applyGaps();
            }
        }
    }

    Process {
        id: wpDirInitProc
        command: ["mkdir", "-p", root.wallpaperDir]
    }

    Component.onCompleted: {
        root._rebuildHiddenSet();
        root._applyGaps();
        wpDirInitProc.running = true;
    }
}
