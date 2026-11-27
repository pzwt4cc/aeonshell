// MpvFullscreenWatcher.qml

pragma Singleton

import "../"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    property var activeVideoMonitors: ({})
    property var _lastPauseState: ({})
    property string _pendingSock: ""
    property string _pendingCmd: ""

    readonly property bool hasVideoWallpapers: Object.keys(activeVideoMonitors).length > 0
    readonly property int watchdogIntervalSec: 15
    readonly property int watchdogRssLimitKb: 700 * 1024

    // Keep Hyprland IPC active
    readonly property var _hyprKeepAlive: Hyprland.workspaces

    function registerVideoWallpaper(mon, filePath) {
        const next = Object.assign({}, root.activeVideoMonitors);
        if (filePath)
            next[mon] = filePath;
        else
            delete next[mon];
        root.activeVideoMonitors = next;
        const pauseCopy = Object.assign({}, root._lastPauseState);
        delete pauseCopy[mon];
        root._lastPauseState = pauseCopy;
    }

    function _sendMpvPause(mon, pause) {
        if (!root.activeVideoMonitors[mon])
            return;
        if (root._lastPauseState[mon] === pause)
            return;
        const copy = Object.assign({}, root._lastPauseState);
        copy[mon] = pause;
        root._lastPauseState = copy;

        root._pendingSock = "/tmp/aeonshell-mpv-" + mon + ".sock";
        root._pendingCmd = JSON.stringify({
            command: ["set_property", "pause", pause]
        }) + "\n";
        mpvSock.connected = false;
        mpvSock.path = root._pendingSock;
        mpvSock.connected = true;
    }

    function _evaluateFullscreen() {
        if (!root.hasVideoWallpapers)
            return;
        const fsByMon = Object.create(null);
        const workspaces = Hyprland.workspaces.values;
        for (let i = 0; i < workspaces.length; i++) {
            const ws = workspaces[i];
            if (!ws || !ws.active)
                continue;
            const ipc = ws.lastIpcObject;
            if (ipc && ipc.monitor && ipc.hasfullscreen) {
                fsByMon[ipc.monitor] = true;
            }
        }
        const tl = Hyprland.activeToplevel;
        if (tl && tl.monitor && tl.lastIpcObject && tl.lastIpcObject.fullscreen && tl.lastIpcObject.fullscreen !== 0) {
            fsByMon[tl.monitor.name] = true;
        }
        for (const mon in root.activeVideoMonitors) {
            root._sendMpvPause(mon, Boolean(fsByMon[mon]));
        }
    }

    Socket {
        id: mpvSock
        onConnectionStateChanged: {
            if (connected && root._pendingCmd) {
                write(root._pendingCmd);
                flush();
                connected = false;
            }
        }
        onError: connected = false
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.hasVideoWallpapers)
                return;
            if (event.name === "fullscreen" || event.name === "activewindow" || event.name === "activewindowv2" || event.name === "workspace" || event.name === "focusedmon") {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();
                evalDebounce.restart();
            }
        }
        function onActiveToplevelChanged() {
            if (root.hasVideoWallpapers)
                evalDebounce.restart();
        }
    }

    Timer {
        id: evalDebounce
        interval: 40
        onTriggered: root._evaluateFullscreen()
    }

    // Seed active video wallpapers on startup if /tmp/aeonshell-video-wp already exists
    Process {
        id: seedProc
        running: true
        command: ["sh", "-c", "for f in /tmp/aeonshell-video-wp/*; do [ -f \"$f\" ] && printf '%s|%s\\n' \"${f##*/}\" \"$(cat \"$f\")\"; done 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(Boolean);
                if (lines.length === 0)
                    return;
                const map = Object.assign({}, root.activeVideoMonitors);
                for (const l of lines) {
                    const idx = l.indexOf("|");
                    if (idx > 0)
                        map[l.slice(0, idx)] = l.slice(idx + 1).trim();
                }
                root.activeVideoMonitors = map;
            }
        }
    }

    Timer {
        interval: root.watchdogIntervalSec * 1000
        running: root.hasVideoWallpapers
        repeat: true
        onTriggered: if (!mpvWatchdogProc.running)
            mpvWatchdogProc.running = true
    }

    Process {
        id: mpvWatchdogProc
        command: ["sh", "-c", "mpvopts='no-audio loop-file=inf hwdec=auto vo=gpu gpu-context=wayland cache=no demuxer-max-bytes=32MiB demuxer-max-back-bytes=16MiB vd-lavc-threads=2'; " + "for f in /tmp/aeonshell-video-wp/*; do " + "  [ -f \"$f\" ] || continue; " + "  mon=\"${f##*/}\"; file=$(cat \"$f\" 2>/dev/null); " + "  [ -f \"$file\" ] || continue; " + "  sock=\"/tmp/aeonshell-mpv-$mon.sock\"; " + "  pid=$(pgrep -f \"input-ipc-server=$sock\" | head -n1); " + "  [ -n \"$pid\" ] || continue; " + "  rss=$(ps -o rss= -p \"$pid\" 2>/dev/null | tr -d ' '); " + "  [ -n \"$rss\" ] || continue; " + "  if [ \"$rss\" -gt " + root.watchdogRssLimitKb + " ]; then " + "    mpvpaper -o \"$mpvopts input-ipc-server=$sock\" \"$mon\" \"$file\" >/tmp/mpvpaper-watchdog.log 2>&1 & " + "    sleep 0.5; kill \"$pid\" 2>/dev/null; " + "  fi; " + "done"]
    }
}
