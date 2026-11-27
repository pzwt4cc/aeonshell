// AppSettings.qml

pragma Singleton
import "../"
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string confPath: Quickshell.env("HOME") + "/.config/quickshell/settings.conf"
    readonly property string defaultWallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    property string barPosition: "top"
    property bool groupNotificationsBySource: false
    property bool barShowPlayer: true
    property bool barShowTray: true
    property string wallpaperDir: defaultWallpaperDir
    property string launcherHiddenApps: ""
    property string launcherViewMode: "list"

    property bool edgeToEdge: false

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

    function resetDefaults() {
        root.barPosition = "top";
        root.groupNotificationsBySource = false;
        root.barShowPlayer = true;
        root.barShowTray = true;
        root.wallpaperDir = root.defaultWallpaperDir;
        root.launcherViewMode = "list";
        root.edgeToEdge = false;
    }

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
        id: wpDirInitProc
        command: ["mkdir", "-p", root.wallpaperDir]
    }

    Component.onCompleted: {
        root._rebuildHiddenSet();
        wpDirInitProc.running = true;
    }
}
