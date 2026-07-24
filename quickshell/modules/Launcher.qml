// Launcher.qml

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore

PanelWindow {
    id: launcher

    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay

    property bool open: false

    Settings {
        id: launcherSettings
        category: "Launcher"
        property var recentIds: []
    }

    readonly property int maxRecent: 8
    readonly property int headerHeight: 32
    readonly property int appHeight: 60
    readonly property int listSpacing: 2
    readonly property int contentPadding: 16

    function trackLaunch(app) {
        if (!app || !app.id) return;
        let arr = launcherSettings.recentIds.slice();
        let idx = arr.indexOf(app.id);
        if (idx !== -1) arr.splice(idx, 1);
        arr.unshift(app.id);
        if (arr.length > maxRecent) arr = arr.slice(0, maxRecent);
        launcherSettings.recentIds = arr;
    }

    function clearRecent() {
        launcherSettings.recentIds = [];
    }

    function toggle() {
        if (!launcher.open) {
            const mon = Hyprland.focusedMonitor;
            if (mon) {
                for (const s of Quickshell.screens) {
                    if (s.name === mon.name) {
                        launcher.screen = s;
                        break;
                    }
                }
            }
        }
        launcher.open = !launcher.open;
        if (launcher.open) {
            searchText = "";
            selectedIndex = 0;
            commandSelectedIndex = 0;
            wallpaperPickerOpen = false;
            searchInput.forceActiveFocus();
            appsList.positionViewAtIndex(0, ListView.Contain);
        }
    }

    Timer { id: hideTimer; interval: 320 }
    onOpenChanged: {
        if (!open) hideTimer.start();
        else hideTimer.stop();
    }
    visible: open || hideTimer.running

    mask: open ? null : emptyMask
    Region { id: emptyMask }

    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            launcher.toggle();
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (launcher.wallpaperPickerOpen) {
                launcher.closeWallpaperPicker();
            } else if (launcher.commandMode) {
                launcher.searchText = "";
                searchInput.forceActiveFocus();
            } else if (launcher.open) {
                launcher.toggle();
            }
        }
    }

    property string searchText: ""
    property int selectedIndex: 0

    onSearchTextChanged: {
        selectedIndex = 0;
        commandSelectedIndex = 0;
        appsList.positionViewAtIndex(0, ListView.Contain);
    }

    readonly property bool commandMode: searchText.startsWith(">")
    readonly property string commandQuery: commandMode ? searchText.slice(1).toLowerCase() : ""

    readonly property var availableCommands: [
        { id: "wallpaper", label: "Wallpaper", desc: "Browse and set a desktop wallpaper", icon: "󰈟" },
        { id: "random-wallpaper", label: "Random wallpaper", desc: "Pick and apply a random one from your folder", icon: "󰒝" },
        { id: "settings", label: "Settings", desc: "Open aeonshell settings", icon: "󰒓" },
        { id: "settings-keybinds", label: "Settings → Keybinds", desc: "Jump straight to your keybinds", icon: "󰌌" },
        { id: "settings-hyprlock", label: "Settings → Hyprlock", desc: "Jump straight to hyprlock settings", icon: "󰌾" },
        { id: "settings-about", label: "Settings → About", desc: "Jump straight to the about page", icon: "󰋼" },
        { id: "reload", label: "Reload Hyprland", desc: "hyprctl reload — reapply config changes", icon: "󰜉" },
    ]

    readonly property var filteredCommands: {
        if (!commandMode) return [];
        if (commandQuery === "") return availableCommands;
        return availableCommands.filter(function (c) {
            return c.id.indexOf(commandQuery) !== -1 || c.label.toLowerCase().indexOf(commandQuery) !== -1;
        });
    }

    property int commandSelectedIndex: 0

    function activateSelectedCommand() {
        if (commandSelectedIndex < 0 || commandSelectedIndex >= filteredCommands.length) return;
        const cmd = filteredCommands[commandSelectedIndex];

        if (cmd.id === "wallpaper") { openWallpaperPicker(); return; }

        if (cmd.id === "random-wallpaper") { applyRandomWallpaper(); launcher.toggle(); return; }

        if (cmd.id === "reload") { Quickshell.execDetached(["hyprctl", "reload"]); launcher.toggle(); return; }

        if (cmd.id === "settings" || cmd.id.startsWith("settings-")) {
            ShellState.settingsSection = cmd.id === "settings" ? "bar" : cmd.id.slice("settings-".length);
            ShellState.settingsWindowOpen = true;
            launcher.toggle();
            return;
        }
    }

    property bool wallpaperPickerOpen: false
    property int wallpaperIndex: 0
    property var wallpaperFiles: []
    
    property int wpFocusSection: 1 

    readonly property string thumbCacheDir: Quickshell.env("HOME") + "/.cache/aeonshell/wallpaper-thumbs"

    property int thumbGenTick: 0

    readonly property string videoExtRegex: "\\.(mp4|webm|mkv|avi|mov|m4v)$"

    function isVideoFile(name) {
        return new RegExp(videoExtRegex, "i").test(name);
    }

    function isScreenPrimary(screen) {
        if (!screen) return false;
        if (screen.isPrimary) return true;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].x === 0 && screens[i].y === 0) return screen === screens[i];
        }
        return screen === screens[0];
    }

    function isScreenPrimaryByName(name) {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name) return isScreenPrimary(screens[i]);
        }
        return false;
    }

    property string targetScreenName: {
        if (Quickshell.screens.length === 0) return "";
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (isScreenPrimary(Quickshell.screens[i])) return Quickshell.screens[i].name;
        }
        return Quickshell.screens[0].name;
    }

    function openWallpaperPicker() {
        wallpaperPickerOpen = true;
        wallpaperIndex = 0;
        wpFocusSection = 1;
        refreshWallpapers();
    }

    function closeWallpaperPicker() {
        wallpaperPickerOpen = false;
        searchText = "";
        searchInput.forceActiveFocus();
    }

    function refreshWallpapers() {
        if (wallpaperListProc.running) wallpaperListProc.running = false;
        wallpaperListProc.running = true;
    }

    readonly property string persistStateDir: Quickshell.env("HOME") + "/.cache/aeonshell/wallpaper-state"

    function applyWallpaper(path) {
        if (!path) return;
        const esc = path.replace(/'/g, "'\\''");
        const targetMon = launcher.targetScreenName;
        const updateColors = launcher.isScreenPrimaryByName(targetMon);
        const escPersistDir = launcher.persistStateDir.replace(/'/g, "'\\''");

        let cmd = "file='" + esc + "'; mon='" + targetMon + "'; pdir='" + escPersistDir + "'; ";
        cmd += "mkdir -p \"$pdir\" 2>/dev/null; ";
        cmd += "ext=$(echo \"${file##*.}\" | tr '[:upper:]' '[:lower:]'); ";
        
        cmd += "if [[ \"$ext\" =~ ^(mp4|webm|mkv|avi|mov|m4v)$ ]]; then ";
        cmd += "  pkill -f \"mpvpaper .*$mon\" 2>/dev/null; ";
        cmd += "  mkdir -p /tmp/aeonshell-video-wp 2>/dev/null; echo \"$file\" > \"/tmp/aeonshell-video-wp/$mon\"; ";
        cmd += "  echo \"video|$file\" > \"$pdir/$mon\"; ";
        cmd += "  mpvpaper -o \"no-audio loop-file=inf hwdec=auto vo=gpu gpu-context=wayland cache=no demuxer-max-bytes=32MiB demuxer-max-back-bytes=16MiB vd-lavc-threads=2 input-ipc-server=/tmp/aeonshell-mpv-$mon.sock\" \"$mon\" \"$file\" >/tmp/mpvpaper-apply.log 2>&1 & disown; ";
        if (updateColors) {
            cmd += "  ffmpeg -y -i \"$file\" -vframes 1 /tmp/wp_frame.jpg >/dev/null 2>&1; ";
            cmd += "  wal -i /tmp/wp_frame.jpg -n -q 2>/dev/null; ";
        }
        cmd += "else ";
        cmd += "  pkill -f \"mpvpaper .*$mon\" 2>/dev/null; ";
        cmd += "  rm -f \"/tmp/aeonshell-video-wp/$mon\" 2>/dev/null; ";
        cmd += "  echo \"image|$file\" > \"$pdir/$mon\"; ";
        cmd += "  pgrep -x awww-daemon >/dev/null 2>&1 || (awww-daemon >/tmp/awww-daemon.log 2>&1 & disown; sleep 0.4); ";
        cmd += "  awww img \"$file\" -o \"$mon\" --transition-type wipe --transition-fps 60 --transition-duration 0.7 >/tmp/awww-apply.log 2>&1; ";
        if (updateColors) {
            cmd += "  wal -i \"$file\" -n -q 2>/dev/null; ";
        }
        cmd += "fi";

        wallpaperApplyProc.command = ["bash", "-c", cmd];
        wallpaperApplyProc.running = true;
    }

    function applyRandomWallpaper() {
        if (randomWallpaperProc.running) randomWallpaperProc.running = false;
        randomWallpaperProc.running = true;
    }

    Process {
        id: randomWallpaperProc
        readonly property string _escDir: AppSettings.wallpaperDir.replace(/'/g, "'\\''")
        command: ["bash", "-c",
            "d='" + _escDir + "'; mkdir -p \"$d\" 2>/dev/null; " +
            "ls -1 \"$d\" 2>/dev/null | grep -Ei '\\.(jpg|jpeg|png|webp|bmp|gif|mp4|webm|mkv|avi|mov|m4v)$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                    .map(function (s) { return s.trim(); })
                    .filter(function (s) { return s.length > 0; });
                if (lines.length === 0) return;
                const pick = lines[Math.floor(Math.random() * lines.length)];
                launcher.applyWallpaper(AppSettings.wallpaperDir + "/" + pick);
            }
        }
    }

    Process {
        id: wallpaperListProc
        readonly property string _escDir: AppSettings.wallpaperDir.replace(/'/g, "'\\''")
        command: ["bash", "-c",
            "d='" + _escDir + "'; mkdir -p \"$d\" 2>/dev/null; " +
            "ls -1 \"$d\" 2>/dev/null | grep -Ei '\\.(jpg|jpeg|png|webp|bmp|gif|mp4|webm|mkv|avi|mov|m4v)$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                    .map(function (s) { return s.trim(); })
                    .filter(function (s) { return s.length > 0; });
                launcher.wallpaperFiles = lines;
                launcher.generateMissingThumbs();
            }
        }
    }

    Process {
        id: wallpaperThumbProc
        onExited: launcher.thumbGenTick++
    }

    function generateMissingThumbs() {
        const videos = launcher.wallpaperFiles.filter(f => launcher.isVideoFile(f));
        if (videos.length === 0) return;
        if (wallpaperThumbProc.running) wallpaperThumbProc.running = false;

        const escDir = AppSettings.wallpaperDir.replace(/'/g, "'\\''");
        const escThumbDir = launcher.thumbCacheDir.replace(/'/g, "'\\''");
        const script =
            "d='" + escDir + "'; td='" + escThumbDir + "'; mkdir -p \"$td\" 2>/dev/null; " +
            "printf '%s\\n' \"$@\" | xargs -P 4 -I{} bash -c '" +
            "thumb=\"$1/{}.jpg\"; " +
            "[ -f \"$thumb\" ] || ffmpeg -y -ss 00:00:01 -i \"$2/{}\" -frames:v 1 -vf scale=360:-1 -q:v 4 \"$thumb\" >>/tmp/aeonshell-thumbs.log 2>&1" +
            "' _ \"$td\" \"$d\"";

        wallpaperThumbProc.command = ["bash", "-c", script, "bash"].concat(videos);
        wallpaperThumbProc.running = true;
    }

    Process {
        id: wallpaperApplyProc
    }

    property int watchdogInterval: 15
    property int watchdogRssLimitMb: 700

    Timer {
        interval: launcher.watchdogInterval * 1000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: mpvWatchdogProc.running = true
    }

    Process {
        id: mpvWatchdogProc
        command: ["bash", "-c",
            "sd='/tmp/aeonshell-video-wp'; [ -d \"$sd\" ] || exit 0; " +
            "mpvopts='no-audio loop-file=inf hwdec=auto vo=gpu gpu-context=wayland cache=no demuxer-max-bytes=32MiB demuxer-max-back-bytes=16MiB vd-lavc-threads=2'; " +
            "for f in \"$sd\"/*; do " +
            "  [ -e \"$f\" ] || continue; " +
            "  mon=$(basename \"$f\"); file=$(cat \"$f\" 2>/dev/null); " +
            "  [ -n \"$file\" ] || continue; " +
            "  [ -f \"$file\" ] || continue; " +
            "  pid=$(pgrep -f \"mpvpaper .*$mon\" | head -n1); " +
            "  [ -n \"$pid\" ] || continue; " +
            "  rss=$(ps -o rss= -p \"$pid\" 2>/dev/null | tr -d ' '); " +
            "  [ -n \"$rss\" ] || continue; " +
            "  limit=$((" + launcher.watchdogRssLimitMb + " * 1024)); " +
            "  if [ \"$rss\" -gt \"$limit\" ]; then " +
            "    mpvpaper -o \"$mpvopts input-ipc-server=/tmp/aeonshell-mpv-$mon.sock\" \"$mon\" \"$file\" >/tmp/mpvpaper-watchdog.log 2>&1 & disown; " +
            "    sleep 0.5; " +
            "    kill \"$pid\" 2>/dev/null; " +
            "  fi; " +
            "done"]
    }

    readonly property var _mpvWatcherKeepAlive: MpvFullscreenWatcher

    readonly property var allApps: {
        let list = [...DesktopEntries.applications.values];
        list = list.filter(function (a) { return a.name && !a.noDisplay; });
        list.sort(function (a, b) { return a.name.localeCompare(b.name); });
        return list;
    }

    readonly property var appsById: {
        let m = {};
        for (const a of allApps) m[a.id] = a;
        return m;
    }

    readonly property var recentApps: {
        let list = [];
        for (const id of launcherSettings.recentIds) {
            const a = appsById[id];
            if (a) list.push(a);
        }
        return list;
    }

    readonly property var filteredApps: {
        if (searchText === "") return allApps;
        const q = searchText.toLowerCase();

        let scored = [];
        for (const a of allApps) {
            const name = (a.name || "").toLowerCase();
            const comment = (a.comment || "").toLowerCase();
            const keywords = ((a.keywords || []).join(" ")).toLowerCase();
            const categories = ((a.categories || []).join(" ")).toLowerCase();
            let score = -1;
            if (name === q) score = 100;
            else if (name.startsWith(q)) score = 90;
            else if (name.split(" ").some(w => w.startsWith(q))) score = 75;
            else if (name.includes(q)) score = 60;
            else if (keywords.includes(q)) score = 45;
            else if (comment.includes(q)) score = 30;
            else if (categories.includes(q)) score = 15;
            if (score >= 0) scored.push({ app: a, score: score });
        }
        scored.sort((x, y) => (y.score - x.score) || x.app.name.localeCompare(y.app.name));
        return scored.map(s => s.app);
    }

    readonly property var flatModel: {
        let fm = [];
        if (searchText === "") {
            if (recentApps.length > 0) {
                fm.push({ kind: "header", label: "Recently used", clearable: true });
                for (const a of recentApps) fm.push({ kind: "app", app: a });
            }
            const recentSet = new Set(recentApps.map(a => a.id));
            const rest = allApps.filter(a => !recentSet.has(a.id));
            if (rest.length > 0) {
                fm.push({ kind: "header", label: "All applications", clearable: false });
                for (const a of rest) fm.push({ kind: "app", app: a });
            }
        } else {
            for (const a of filteredApps) fm.push({ kind: "app", app: a });
        }
        return fm;
    }

    readonly property var appPositions: {
        let positions = [];
        for (let i = 0; i < flatModel.length; i++) {
            if (flatModel[i].kind === "app") positions.push(i);
        }
        return positions;
    }

    function launchSelected() {
        if (selectedIndex < 0 || selectedIndex >= appPositions.length) return;
        const entry = flatModel[appPositions[selectedIndex]];
        entry.app.execute();
        launcher.toggle();
        launcher.trackLaunch(entry.app);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (launcher.open) launcher.toggle()
    }

    Rectangle {
        anchors.fill: box
        anchors.margins: -3
        radius: box.radius + 3
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: box.opacity * 0.3
       
        scale: box.scale
        transformOrigin: box.transformOrigin
        z: box.z - 1
    }

    Rectangle {
        id: box
        width: launcher.wallpaperPickerOpen ? 780 : 700
        height: launcher.wallpaperPickerOpen ? 340 : 640
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        anchors.horizontalCenter: parent.horizontalCenter

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

        radius: 28
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent; onClicked: { searchInput.forceActiveFocus(); } }

        transformOrigin: Item.Bottom
        scale: launcher.open ? 1.0 : 0.9
        opacity: launcher.open ? 1.0 : 0.0
        y: launcher.open ? 0 : 44

        Behavior on scale {
            NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        Behavior on y {
            NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.28
            height: 3
            visible: !launcher.wallpaperPickerOpen
            
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.0) }
                GradientStop { position: 0.5; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.85) }
                GradientStop { position: 1.0; color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.0) }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: launcher.contentPadding
            anchors.topMargin: launcher.wallpaperPickerOpen ? 8 : launcher.contentPadding + 12
            spacing: launcher.wallpaperPickerOpen ? 6 : 14

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: launcher.wallpaperPickerOpen ? 0 : 48
                opacity: launcher.wallpaperPickerOpen ? 0 : 1
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                
                radius: 24
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                border.color: searchInput.activeFocus && (!launcher.wallpaperPickerOpen || launcher.wpFocusSection === 0) ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4) : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: launcher.contentPadding
                    anchors.rightMargin: launcher.contentPadding
                    spacing: 10

                    Text {
                        id: searchIcon
                        Layout.alignment: Qt.AlignVCenter
                        text: "󰍉"
                        font.pixelSize: 16
                        color: searchInput.activeFocus && (!launcher.wallpaperPickerOpen || launcher.wpFocusSection === 0)
                            ? Colors.primary
                            : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)

                        scale: launcher.searchText.length > 0 ? 1.1 : 1.0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        readOnly: launcher.wallpaperPickerOpen 
                        
                        placeholderText: launcher.wallpaperPickerOpen
                            ? "Esc to go back"
                            : (launcher.commandMode ? "Type a command…" : "Search applications...")
                        placeholderTextColor: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                        text: launcher.searchText

                        onTextChanged: launcher.searchText = text

                        font.pixelSize: 17
                        color: Colors.surfaceText
                        background: Item {}
     
                        leftPadding: 0
                        topPadding: 0
                        bottomPadding: 0

                        Keys.onEscapePressed: {
                            if (launcher.wallpaperPickerOpen) {
                                launcher.closeWallpaperPicker();
                            } else if (launcher.commandMode) {
                                launcher.searchText = "";
                            } else {
                                launcher.toggle();
                            }
                        }

                        Keys.onLeftPressed: (event) => {
                            if (!launcher.wallpaperPickerOpen || launcher.wallpaperFiles.length === 0) {
                                event.accepted = false;
                                return;
                            }
                            
                            event.accepted = true;
                            if (launcher.wpFocusSection === 0) {
                                const screens = Quickshell.screens;
                                let idx = screens.findIndex(s => s.name === launcher.targetScreenName);
                                if (idx > 0) launcher.targetScreenName = screens[idx - 1].name;
                                else launcher.targetScreenName = screens[screens.length - 1].name;
                            } else if (launcher.wpFocusSection === 1) {
                                const n = launcher.wallpaperFiles.length;
                                launcher.wallpaperIndex = (launcher.wallpaperIndex - 1 + n) % n;
                            }
                        }

                        Keys.onRightPressed: (event) => {
                            if (!launcher.wallpaperPickerOpen || launcher.wallpaperFiles.length === 0) {
                                event.accepted = false;
                                return;
                            }

                            event.accepted = true;
                            if (launcher.wpFocusSection === 0) {
                                const screens = Quickshell.screens;
                                let idx = screens.findIndex(s => s.name === launcher.targetScreenName);
                                if (idx < screens.length - 1) launcher.targetScreenName = screens[idx + 1].name;
                                else launcher.targetScreenName = screens[0].name;
                            } else if (launcher.wpFocusSection === 1) {
                                const n = launcher.wallpaperFiles.length;
                                launcher.wallpaperIndex = (launcher.wallpaperIndex + 1) % n;
                            }
                        }

                        Keys.onUpPressed: (event) => {
                            if (launcher.wallpaperPickerOpen) {
                                if (launcher.wpFocusSection === 1) {
                                    launcher.wpFocusSection = 0;
                                }
                                event.accepted = true;
                                return;
                            }
                            if (launcher.commandMode) {
                                if (launcher.filteredCommands.length === 0) return;
                                launcher.commandSelectedIndex = Math.max(0, launcher.commandSelectedIndex - 1);
                                return;
                            }
                            if (launcher.appPositions.length === 0) return;
                            launcher.selectedIndex = Math.max(0, launcher.selectedIndex - 1);
                            if (launcher.selectedIndex === 0) {
                                appsList.positionViewAtIndex(0, ListView.Contain);
                            } else {
                                appsList.positionViewAtIndex(launcher.appPositions[launcher.selectedIndex], ListView.Contain);
                            }
                        }

                        Keys.onDownPressed: (event) => {
                            if (launcher.wallpaperPickerOpen) {
                                if (launcher.wpFocusSection === 0) {
                                    launcher.wpFocusSection = 1;
                                }
                                event.accepted = true;
                                return;
                            }
                            if (launcher.commandMode) {
                                if (launcher.filteredCommands.length === 0) return;
                                launcher.commandSelectedIndex = Math.min(launcher.filteredCommands.length - 1, launcher.commandSelectedIndex + 1);
                                return;
                            }
                            if (launcher.appPositions.length === 0) return;
                            launcher.selectedIndex = Math.min(launcher.appPositions.length - 1, launcher.selectedIndex + 1);
                            appsList.positionViewAtIndex(launcher.appPositions[launcher.selectedIndex], ListView.Contain);
                        }

                        Keys.onReturnPressed: (event) => {
                            if (launcher.wallpaperPickerOpen) {
                                if (launcher.wallpaperFiles.length === 0) return;
                                launcher.applyWallpaper(AppSettings.wallpaperDir + "/" + launcher.wallpaperFiles[launcher.wallpaperIndex]);
                                event.accepted = true;
                                return;
                            }
                            if (launcher.commandMode) {
                                launcher.activateSelectedCommand();
                                return;
                            }
                            launcher.launchSelected();
                        }
                    }

                    Text {
                        visible: launcher.searchText.length > 0
                        text: "󰅖"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                        font.pixelSize: 14
                        TapHandler {
                            onTapped: 
                            {
                                launcher.searchText = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: launcher.wallpaperPickerOpen ? 0 : 1
                Layout.topMargin: launcher.wallpaperPickerOpen ? -14 : 0
                opacity: launcher.wallpaperPickerOpen ? 0 : 1
                clip: true
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on Layout.topMargin { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
            }

            Item {
                id: listWrap
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: -8
                Layout.rightMargin: -8
                clip: true

                ListView {
                    id: appsList
                    anchors.fill: parent
        
                    visible: !launcher.commandMode && !launcher.wallpaperPickerOpen
                    clip: true
                    spacing: launcher.listSpacing
                    model: launcher.flatModel
                    
  
                    currentIndex: (launcher.selectedIndex >= 0 && launcher.selectedIndex < launcher.appPositions.length) 
                                  ? launcher.appPositions[launcher.selectedIndex] 
                                  : -1

                    onCountChanged: {
                        if (launcher.selectedIndex >= launcher.appPositions.length) {
                            launcher.selectedIndex = Math.max(0, launcher.appPositions.length - 1);
                        }
                    }

                    delegate: Item {
                        id: rowRoot
                        width: ListView.view.width
        
                        height: modelData.kind === "header" ? launcher.headerHeight : launcher.appHeight

                        readonly property int myAppIndex: modelData.kind === "app" ? launcher.appPositions.indexOf(index) : -1
                        readonly property bool isCurrent: myAppIndex !== -1 && myAppIndex === launcher.selectedIndex

                        RowLayout {
                            visible: modelData.kind === "header"
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Text {
                                text: modelData.kind === "header" ? modelData.label : ""
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                font.pixelSize: 12
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: modelData.kind === "header" && modelData.clearable
                                text: "Clear"
                                color: clearHover.hovered ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                font.pixelSize: 12
                                Behavior on color { ColorAnimation { duration: 100 } }

                                HoverHandler { id: clearHover }
                                TapHandler {
                                    onTapped: launcher.clearRecent()
                                }
                            }
                        }

                        Rectangle {
                            visible: modelData.kind === "app"
                            anchors.fill: parent
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            radius: 12

                            color: rowRoot.isCurrent
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14)
                                : (hover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent")
                            
                            border.color: rowRoot.isCurrent 
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) 
                                : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 130 } }
                            Behavior on border.color { ColorAnimation { duration: 130 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 14

                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: 11
                                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.10)

                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: 28
                                        source: modelData.kind === "app" ? Quickshell.iconPath(modelData.app.icon, true) : ""
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: modelData.kind === "app" ? modelData.app.name : ""
                                        color: Colors.surfaceText
                                        font.pixelSize: 15
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        visible: modelData.kind === "app" && !!modelData.app.comment
                                        text: modelData.kind === "app" ? (modelData.app.comment || "") : ""
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            HoverHandler {
                                id: hover
                                onHoveredChanged: {
                                    if (hovered && rowRoot.myAppIndex !== -1) launcher.selectedIndex = rowRoot.myAppIndex;
                                }
                            }
                            TapHandler {
                                onTapped: {
                                    if (modelData.kind !== "app") return;
                                    modelData.app.execute();
                                    launcher.toggle();
                                    launcher.trackLaunch(modelData.app);
                                }
                            }
                        }
                    }

                    Text {
                        visible: launcher.flatModel.length === 0
                        anchors.centerIn: parent
                        text: "No applications found"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                        font.pixelSize: 15
                    }
                }

                ListView {
                    id: commandsList
                    anchors.fill: parent
                    visible: launcher.commandMode && !launcher.wallpaperPickerOpen
                    clip: true
                    spacing: launcher.listSpacing
                    model: launcher.filteredCommands
                    currentIndex: launcher.commandSelectedIndex

                    delegate: Item {
                        width: ListView.view.width
                        height: launcher.appHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            radius: 12
                            color: index === launcher.commandSelectedIndex
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14)
                                : (cmdHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent")
                            border.color: index === launcher.commandSelectedIndex
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35)
                                : "transparent"
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 130 } }
                            Behavior on border.color { ColorAnimation { duration: 130 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 14

                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: 11
                                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.10)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        color: Colors.primary
                                        font.pixelSize: 18
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: modelData.label
                                        color: Colors.surfaceText
                                        font.pixelSize: 15
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.desc
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            HoverHandler {
                                id: cmdHover
                                onHoveredChanged: if (hovered) launcher.commandSelectedIndex = index
                            }
                            TapHandler {
                                onTapped: launcher.activateSelectedCommand()
                            }
                        }
                    }

                    Text {
                        visible: launcher.filteredCommands.length === 0
                        anchors.centerIn: parent
                        text: "No matching commands"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                        font.pixelSize: 15
                    }
                }

                ColumnLayout {
                    id: wallpaperPickerView
                    anchors.fill: parent
                    visible: launcher.wallpaperPickerOpen
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 2
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: launcher.wallpaperFiles.length === 0
                                ? "No wallpapers found in " + AppSettings.wallpaperDir
                                : "Select Monitor & Wallpaper"
                            color: launcher.wpFocusSection === 0 ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 12
                            font.bold: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            visible: launcher.wallpaperFiles.length > 0
                            spacing: 8

                            Repeater {
                                model: Quickshell.screens
                                delegate: Rectangle {
                                    readonly property bool isPrim: launcher.isScreenPrimary(modelData)
                                    readonly property bool isSel: launcher.targetScreenName === modelData.name

                                    implicitWidth: monLayout.implicitWidth + 20
                                    implicitHeight: 28
                                    radius: 7
                                    color: isSel ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2) : (monHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                                    border.color: (isSel || (launcher.wpFocusSection === 0 && monHover.hovered)) ? Colors.primary : Qt.rgba(1, 1, 1, 0.1)
                                    border.width: isSel ? 2 : 1

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        id: monLayout
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text {
                                            text: "󰍹"
                                            font.pixelSize: 12
                                            color: isSel ? Colors.primary : Colors.surfaceText
                                        }
                                        Text {
                                            text: modelData.name + (isPrim ? " (Colors)" : " (Image only)")
                                            font.pixelSize: 11
                                            font.bold: isSel
                                            color: isSel ? Colors.primary : Colors.surfaceText
                                        }
                                    }

                                    HoverHandler { id: monHover }
                                    TapHandler { 
                                        onTapped: {
                                            launcher.targetScreenName = modelData.name;
                                            launcher.wpFocusSection = 0;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: -launcher.contentPadding
                        Layout.rightMargin: -launcher.contentPadding
                        Layout.topMargin: -2
                        clip: true

                        PathView {
                            id: wallpaperStrip
                            anchors.centerIn: parent
                            width: parent.width
                            height: 180
                            model: launcher.wallpaperFiles
                            currentIndex: launcher.wallpaperIndex
                            pathItemCount: Math.min(5, Math.max(1, launcher.wallpaperFiles.length))
                            interactive: true
                            snapMode: PathView.SnapToItem
                            flickDeceleration: 2000
                            highlightMoveDuration: 260
                            
                            preferredHighlightBegin: 0.5
                            preferredHighlightEnd: 0.5

                            onCurrentIndexChanged: launcher.wallpaperIndex = currentIndex

                            readonly property int cardWidth: 240
                            readonly property int cardHeight: 150

                            path: Path {
                                startX: -wallpaperStrip.cardWidth * 0.8
                                startY: wallpaperStrip.height / 2
                                
                                PathAttribute { name: "itemScale"; value: 0.7 }
                                PathAttribute { name: "itemOpacity"; value: 0.3 }
                                PathAttribute { name: "itemZ"; value: 0 }

                                PathLine {
                                    x: wallpaperStrip.width / 2
                                    y: wallpaperStrip.height / 2
                                }
                                
                                PathAttribute { name: "itemScale"; value: 1.0 }
                                PathAttribute { name: "itemOpacity"; value: 1.0 }
                                PathAttribute { name: "itemZ"; value: 10 }

                                PathLine {
                                    x: wallpaperStrip.width + wallpaperStrip.cardWidth * 0.8
                                    y: wallpaperStrip.height / 2
                                }
                                
                                PathAttribute { name: "itemScale"; value: 0.7 }
                                PathAttribute { name: "itemOpacity"; value: 0.3 }
                                PathAttribute { name: "itemZ"; value: 0 }
                            }

                            delegate: Item {
                                id: wpDelegate
                                width: wallpaperStrip.cardWidth
                                height: wallpaperStrip.cardHeight
                                scale: PathView.itemScale
                                opacity: PathView.itemOpacity
                                z: PathView.itemZ

                                readonly property bool isCurrent: PathView.itemScale > 0.95
                                readonly property bool isVideo: launcher.isVideoFile(modelData)

                                readonly property string imgSource: wpDelegate.isVideo
                                    ? ("file://" + launcher.thumbCacheDir + "/" + modelData + ".jpg?g=" + launcher.thumbGenTick)
                                    : ("file://" + AppSettings.wallpaperDir + "/" + modelData)

                                Image {
                                    id: previewImg
                                    anchors.fill: parent
                                    source: wpDelegate.imgSource
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 360
                                    sourceSize.height: 220
                                    visible: status === Image.Ready
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: previewImg.status !== Image.Ready
                                    color: Qt.rgba(0.08, 0.08, 0.08, 1.0)

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            text: wpDelegate.isVideo ? "🎬" : "🖼"
                                            font.pixelSize: 32
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: modelData
                                            color: Colors.surfaceText
                                            font.pixelSize: 11
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.maximumWidth: wpDelegate.width - 20
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: wpDelegate.isVideo && previewImg.status === Image.Ready
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    Text {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: 1
                                        text: "▶"
                                        color: "white"
                                        font.pixelSize: 9
                                    }
                                }
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: wpDelegate.isCurrent ? "transparent" : Qt.rgba(0, 0, 0, 0.3)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: "transparent"
                                    border.color: wpDelegate.isCurrent 
                                        ? Colors.primary 
                                        : Qt.rgba(0.55, 0.55, 0.55, 0.4)
                                    border.width: wpDelegate.isCurrent ? 3 : 1.5
                                    Behavior on border.color { ColorAnimation { duration: 180 } }
                                    Behavior on border.width { NumberAnimation { duration: 180 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        launcher.wpFocusSection = 1;
                                        if (wpDelegate.isCurrent) {
                                            launcher.applyWallpaper(AppSettings.wallpaperDir + "/" + modelData);
                                        } else {
                                            launcher.wallpaperIndex = index;
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: launcher.contentPadding
                            anchors.verticalCenter: wallpaperStrip.verticalCenter
                            text: "‹"
                            font.pixelSize: 24
                            color: launcher.wpFocusSection === 1 ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                            visible: launcher.wallpaperFiles.length > 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                       
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: launcher.contentPadding
                            anchors.verticalCenter: wallpaperStrip.verticalCenter
                            text: "›"
                            font.pixelSize: 24
                            color: launcher.wpFocusSection === 1 ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                            visible: launcher.wallpaperFiles.length > 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    Text {
                        visible: launcher.wallpaperFiles.length > 0
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 2
                        text: (launcher.wallpaperIndex + 1) + " / " + launcher.wallpaperFiles.length
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                        font.pixelSize: 11
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    text: launcher.wallpaperPickerOpen ? "↑ ↓  Select Section" : "↑ ↓  Navigate"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                    font.pixelSize: 11
                }
                Text {
                    text: launcher.wallpaperPickerOpen ? "← →  Choose" : "↵  Open"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                    font.pixelSize: 11
                }
                Text {
                    text: launcher.wallpaperPickerOpen ? "↵  Apply" : ""
                    visible: launcher.wallpaperPickerOpen
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                    font.pixelSize: 11
                }
                Text {
                    text: "Esc  " + ((launcher.wallpaperPickerOpen || launcher.commandMode) ? "Back" : "Close")
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: launcher.wallpaperPickerOpen
                        ? (launcher.wallpaperFiles.length + " wallpapers")
                        : (launcher.commandMode
                            ? (launcher.filteredCommands.length + " commands")
                            : (launcher.appPositions.length + " applications"))
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                    font.pixelSize: 11
                }
            }
        }
    }
}
