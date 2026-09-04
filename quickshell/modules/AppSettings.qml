// AppSettings.qml

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string confDir: Quickshell.env("HOME") + "/.config/hypr/conf"
    readonly property string confPath: root.confDir + "/quickshell.lua"

    property string barPosition: "top"
    property bool groupNotificationsBySource: false
    property bool barShowPlayer: true
    property bool barShowTray: true
    property bool barShowWindows: true
    property string pinnedApps: ""
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string launcherHiddenApps: ""
    property string launcherViewMode: "list"

    property bool edgeToEdge: false

    readonly property int normalGapsIn: 5
    readonly property int normalGapsOut: 10
    readonly property int normalBorderSize: 2
    readonly property int normalRounding: 10

    property bool _applying: false
    property bool _dirReady: false

    // --- pinned apps helpers -------------------------------------------------

    function pinnedList() {
        return root.pinnedApps.length ? root.pinnedApps.split(",") : [];
    }

    function isPinned(cls) {
        return cls ? root.pinnedList().indexOf(cls) !== -1 : false;
    }

    function togglePinned(cls) {
        if (!cls) return;
        let list = root.pinnedList();
        const idx = list.indexOf(cls);
        if (idx !== -1) list.splice(idx, 1);
        else list.push(cls);
        root.pinnedApps = list.join(",");
    }

    // --- launcher hidden-apps helpers ------------------------------------------

    function hiddenAppsList() {
        return root.launcherHiddenApps.length ? root.launcherHiddenApps.split(",") : [];
    }

    function isAppHidden(id) {
        return id ? root.hiddenAppsList().indexOf(id) !== -1 : false;
    }

    function toggleAppHidden(id) {
        if (!id) return;
        let list = root.hiddenAppsList();
        const idx = list.indexOf(id);
        if (idx !== -1) list.splice(idx, 1);
        else list.push(id);
        root.launcherHiddenApps = list.join(",");
    }

    // --- persistence ----------------------------------------------------------

    function _parse(text) {
        root._applying = true;
        const m = text.match(/^\s*barPosition\s*=\s*"([^"]*)"/m);
        if (m) root.barPosition = m[1];
        const g = text.match(/^\s*groupNotificationsBySource\s*=\s*(true|false)/m);
        if (g) root.groupNotificationsBySource = (g[1] === "true");
        const p = text.match(/^\s*barShowPlayer\s*=\s*(true|false)/m);
        if (p) root.barShowPlayer = (p[1] === "true");
        const t = text.match(/^\s*barShowTray\s*=\s*(true|false)/m);
        if (t) root.barShowTray = (t[1] === "true");
        const bw = text.match(/^\s*barShowWindows\s*=\s*(true|false)/m);
        if (bw) root.barShowWindows = (bw[1] === "true");
        const pa = text.match(/^\s*pinnedApps\s*=\s*"([^"]*)"/m);
        if (pa) root.pinnedApps = pa[1];
        const lh = text.match(/^\s*launcherHiddenApps\s*=\s*"([^"]*)"/m);
        if (lh) root.launcherHiddenApps = lh[1];
        const lv = text.match(/^\s*launcherViewMode\s*=\s*"([^"]*)"/m);
        if (lv) root.launcherViewMode = lv[1];
        const w = text.match(/^\s*wallpaperDir\s*=\s*"([^"]*)"/m);
        if (w) root.wallpaperDir = w[1];
        const e = text.match(/^\s*edgeToEdge\s*=\s*(true|false)/m);
        if (e) root.edgeToEdge = (e[1] === "true");
        root._applying = false;
    }

    function _serialize() {
        return "-- Quickshell settings file.\n" +
               "-- Created and rewritten automatically — do not edit by hand,\n" +
               "-- any manual changes will be lost on the next save from the\n" +
               "-- Quickshell settings window.\n" +
               "--\n" +
               "-- Import in your Lua config:\n" +
               "--   local quickshell = dofile(os.getenv(\"HOME\") .. \"/.config/hypr/conf/quickshell.lua\")\n\n" +
               "return {\n" +
               "    barPosition = \"" + root.barPosition + "\",\n" +
               "    groupNotificationsBySource = " + (root.groupNotificationsBySource ? "true" : "false") + ",\n" +
               "    barShowPlayer = " + (root.barShowPlayer ? "true" : "false") + ",\n" +
               "    barShowTray = " + (root.barShowTray ? "true" : "false") + ",\n" +
               "    barShowWindows = " + (root.barShowWindows ? "true" : "false") + ",\n" +
               "    pinnedApps = \"" + root.pinnedApps + "\",\n" +
               "    launcherHiddenApps = \"" + root.launcherHiddenApps + "\",\n" +
               "    launcherViewMode = \"" + root.launcherViewMode + "\",\n" +
               "    wallpaperDir = \"" + root.wallpaperDir + "\",\n" +
               "    edgeToEdge = " + (root.edgeToEdge ? "true" : "false") + ",\n" +
               "}\n";
    }

    property bool _writing: false

    function _save() {
        if (root._applying || !root._dirReady) return;
        root._writing = true;
        confFile.setText(root._serialize());
    }

    function _applyGaps() {
        const gIn = root.edgeToEdge ? 0 : root.normalGapsIn;
        const gOut = root.edgeToEdge ? 0 : root.normalGapsOut;
        const border = root.edgeToEdge ? 0 : root.normalBorderSize;
        const rounding = root.edgeToEdge ? 0 : root.normalRounding;
        gapsProc.command = ["hyprctl", "--batch",
            "keyword general:gaps_in " + gIn +
            " ; keyword general:gaps_out " + gOut +
            " ; keyword general:border_size " + border +
            " ; keyword decoration:rounding " + rounding];
        gapsProc.running = true;
    }

    onBarPositionChanged: root._save()
    onGroupNotificationsBySourceChanged: root._save()
    onBarShowPlayerChanged: root._save()
    onBarShowTrayChanged: root._save()
    onBarShowWindowsChanged: root._save()
    onPinnedAppsChanged: root._save()
    onLauncherHiddenAppsChanged: root._save()
    onLauncherViewModeChanged: root._save()
    onWallpaperDirChanged: root._save()
    onEdgeToEdgeChanged: {
        root._save();
        root._applyGaps();
    }

    Process { id: gapsProc }

    Process {
        id: hyprEventWatcher
        running: true
        command: [
            "bash", "-c",
            "stdbuf -oL socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null | " +
            "stdbuf -oL grep --line-buffered -E 'configreloaded>>|monitoradded|monitorremoved'"
        ]
        stdout: SplitParser {
            onRead: text => {
                if (text.trim()) root._applyGaps();
            }
        }
    }

    Process {
        id: mkdirProc
        command: ["bash", "-c", "mkdir -p '" + root.confDir + "' '" + root.wallpaperDir.replace(/'/g, "'\\''") + "'"]
        onExited: root._dirReady = true
    }

    FileView {
        id: confFile
        path: root.confPath
        watchChanges: true
        printErrors: false

        onLoaded: {
            root._parse(confFile.text());
            root._applyGaps();
        }
        onLoadFailed: error => {
            root._dirReady = true;
            root._save();
            root._applyGaps();
        }
        onFileChanged: {
            if (root._writing) {
                root._writing = false;
                return;
            }
            reload();
        }
    }

    Component.onCompleted: mkdirProc.running = true
}