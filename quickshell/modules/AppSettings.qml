// AppSettings.qml
//
// Singleton for persistent shell settings. Not stored in Quickshell's
// internal store, but as a plain text file in ~/.config/hypr/conf/ —
// the same place where your monitors.conf, keybinds.conf, etc. live.
// The file is created and fully rewritten automatically on every save —
// there's no need to edit it by hand (and no point, any manual edits
// would be lost on the next save from the settings window).
//
// The format is native Hyprland variable syntax ($name = value), so
// the file can be safely sourced via "source =" in hyprland.conf: it's
// just variable declarations that have no effect until something
// actually uses them. Future user keybinds will land in the same file
// as plain bind = ... lines, which Hyprland will parse on its own.
//
// Temporary UI state (e.g. whether the settings window is open) is
// deliberately NOT stored here — there's a separate ShellState.qml
// singleton for that, which is never written to disk.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string confDir: Quickshell.env("HOME") + "/.config/hypr/conf"
    readonly property string confPath: root.confDir + "/quickshell.conf"

    property string barPosition: "top"
    property bool groupNotificationsBySource: false
    property bool barShowPlayer: true
    property bool barShowTray: true
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    property bool edgeToEdge: false

    readonly property int normalGapsIn: 5
    readonly property int normalGapsOut: 10
    readonly property int normalBorderSize: 2
    readonly property int normalRounding: 10

    property bool _applying: false
    property bool _dirReady: false

    function _parse(text) {
        root._applying = true;
        const m = text.match(/^\s*\$quickshell_barPosition\s*=\s*(\S+)/m);
        if (m) root.barPosition = m[1];
        const g = text.match(/^\s*\$quickshell_groupNotificationsBySource\s*=\s*(\S+)/m);
        if (g) root.groupNotificationsBySource = (g[1] === "true" || g[1] === "1");
        const p = text.match(/^\s*\$quickshell_barShowPlayer\s*=\s*(\S+)/m);
        if (p) root.barShowPlayer = (p[1] === "true" || p[1] === "1");
        const t = text.match(/^\s*\$quickshell_barShowTray\s*=\s*(\S+)/m);
        if (t) root.barShowTray = (t[1] === "true" || t[1] === "1");
        const w = text.match(/^\s*\$quickshell_wallpaperDir\s*=\s*(.+)\s*$/m);
        if (w) root.wallpaperDir = w[1].trim();
        const e = text.match(/^\s*\$quickshell_edgeToEdge\s*=\s*(\S+)/m);
        if (e) root.edgeToEdge = (e[1] === "true" || e[1] === "1");
        root._applying = false;
    }

    function _serialize() {
        return "# Quickshell settings file.\n" +
               "# Created and rewritten automatically — do not edit by hand,\n" +
               "# any manual changes will be lost on the next save from the\n" +
               "# Quickshell settings window.\n" +
               "#\n" +
               "# Source it once in hyprland.conf:\n" +
               "#   source = ~/.config/hypr/conf/quickshell.conf\n\n" +
               "$quickshell_barPosition = " + root.barPosition + "\n" +
               "$quickshell_groupNotificationsBySource = " + (root.groupNotificationsBySource ? "true" : "false") + "\n" +
               "$quickshell_barShowPlayer = " + (root.barShowPlayer ? "true" : "false") + "\n" +
               "$quickshell_barShowTray = " + (root.barShowTray ? "true" : "false") + "\n" +
               "$quickshell_wallpaperDir = " + root.wallpaperDir + "\n" +
               "$quickshell_edgeToEdge = " + (root.edgeToEdge ? "true" : "false") + "\n";
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