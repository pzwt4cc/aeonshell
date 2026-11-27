// Launcher.qml

pragma ComponentBehavior: Bound

import "../"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore

Scope {
    id: root

    property bool open: false
    property string searchText: ""
    property int selectedIndex: 0
    property int commandSelectedIndex: 0
    property bool hiddenAppsMode: false

    property bool wallpaperPickerOpen: false
    property int wallpaperIndex: 0
    property var wallpaperFiles: []
    property int wpFocusSection: 1
    property int thumbGenTick: 0

    property bool _applyingWallpaper: false
    property string _queuedWallpaperPath: ""
    property string _activeApplyMon: ""
    property bool _activeApplyIsVideo: false
    property bool _activeApplyUpdateColors: false
    property string _activeApplyPath: ""
    property string _activeFrameFile: ""

    readonly property int maxRecent: 8
    readonly property int headerHeight: 32
    readonly property int appHeight: 60
    readonly property int listSpacing: 2
    readonly property int contentPadding: 16
    readonly property string thumbCacheDir: AppSettings.thumbCacheDir
    readonly property string persistStateDir: AppSettings.persistStateDir
    readonly property string videoExtRegex: "\\.(mp4|webm|mkv|avi|mov|m4v)$"
    readonly property bool gridView: AppSettings.launcherViewMode === "grid"

    property var activeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property var winItem: winLoader.item
    property string targetScreenName: {
        if (Quickshell.screens.length === 0)
            return "";
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (isScreenPrimary(Quickshell.screens[i]))
                return Quickshell.screens[i].name;
        }
        return Quickshell.screens[0].name;
    }

    Settings {
        id: launcherSettings
        category: "Launcher"
        location: "file://" + AppSettings.confPath
        property var recentIds: []
    }

    Timer {
        id: hideTimer
        interval: 320
        onTriggered: {
            root.wallpaperFiles = [];
            root.wallpaperPickerOpen = false;
            root.hiddenAppsMode = false;
        }
    }

    onOpenChanged: {
        ShellState.launcherOpen = open;
        if (!open) {
            hideTimer.start();
        } else {
            hideTimer.stop();
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            root.toggle();
        }
    }

    Connections {
        target: ShellState
        function onOpenWallpaperRequestedChanged() {
            if (ShellState.openWallpaperRequested) {
                ShellState.openWallpaperRequested = false;
                root.open = true;
                root.openWallpaperPicker();
            }
        }
    }

    function toggle() {
        if (!root.open) {
            const mon = Hyprland.focusedMonitor;
            if (mon) {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === mon.name) {
                        root.activeScreen = Quickshell.screens[i];
                        break;
                    }
                }
            } else if (Quickshell.screens.length > 0) {
                root.activeScreen = Quickshell.screens[0];
            }
            root.searchText = "";
            root.selectedIndex = 0;
            root.commandSelectedIndex = 0;
            root.wallpaperPickerOpen = false;
            root.hiddenAppsMode = false;
            root.open = true;
            if (root.winItem) {
                root.winItem.focusSearch();
                root.winItem.resetListScroll();
            }
        } else {
            root.open = false;
        }
    }

    function trackLaunch(app) {
        if (!app || !app.id)
            return;
        let arr = launcherSettings.recentIds.slice();
        let idx = arr.indexOf(app.id);
        if (idx !== -1)
            arr.splice(idx, 1);
        arr.unshift(app.id);
        if (arr.length > maxRecent)
            arr = arr.slice(0, maxRecent);
        launcherSettings.recentIds = arr;
    }

    function clearRecent() {
        launcherSettings.recentIds = [];
    }

    function isVideoFile(name) {
        return new RegExp(videoExtRegex, "i").test(name);
    }

    function isScreenPrimary(screen) {
        if (!screen)
            return false;
        if (screen.isPrimary)
            return true;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].x === 0 && screens[i].y === 0)
                return screen === screens[i];
        }
        return screen === screens[0];
    }

    function isScreenPrimaryByName(name) {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return isScreenPrimary(screens[i]);
        }
        return false;
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
        if (root.winItem)
            root.winItem.focusSearch();
    }

    function refreshWallpapers() {
        if (wallpaperListProc.running)
            wallpaperListProc.running = false;
        wallpaperListProc.command = ["sh", "-c", "mkdir -p \"$1\" 2>/dev/null; find \"$1\" -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null | grep -Ei '\\.(jpg|jpeg|png|webp|bmp|gif|mp4|webm|mkv|avi|mov|m4v)$' | sort", "sh", AppSettings.wallpaperDir];
        wallpaperListProc.running = true;
    }

    function applyWallpaper(path) {
        if (!path)
            return;
        if (root._applyingWallpaper) {
            root._queuedWallpaperPath = path;
            return;
        }
        root._applyingWallpaper = true;

        const targetMon = root.targetScreenName;
        const updateColors = root.isScreenPrimaryByName(targetMon);
        const isVid = root.isVideoFile(path);
        const frameFile = (isVid && updateColors) ? ("/tmp/aeonshell-wp-frame-" + Date.now() + ".jpg") : "";

        root._activeApplyMon = targetMon;
        root._activeApplyIsVideo = isVid;
        root._activeApplyUpdateColors = updateColors;
        root._activeApplyPath = path;
        root._activeFrameFile = frameFile;

        let script;
        if (isVid) {
            script = "file=\"$1\"; mon=\"$2\"; pdir=\"$3\"; frame=\"$4\"; " + "mkdir -p \"$pdir\" /tmp/aeonshell-video-wp 2>/dev/null; " + "pkill -f \"input-ipc-server=/tmp/aeonshell-mpv-${mon}.sock\" 2>/dev/null; " + "awww clear -o \"$mon\" >/dev/null 2>&1 || true; " + "printf '%s\\n' \"$file\" > \"/tmp/aeonshell-video-wp/$mon\"; " + "printf 'video|%s\\n' \"$file\" > \"$pdir/$mon\"; " + "mpvpaper -o \"no-audio loop-file=inf hwdec=auto vo=gpu gpu-context=wayland cache=no demuxer-max-bytes=32MiB demuxer-max-back-bytes=16MiB vd-lavc-threads=2 input-ipc-server=/tmp/aeonshell-mpv-${mon}.sock\" \"$mon\" \"$file\" >/tmp/mpvpaper-apply.log 2>&1 & disown; " + "if [ -n \"$frame\" ]; then ffmpeg -y -ss 00:00:01 -i \"$file\" -frames:v 1 \"$frame\" >/dev/null 2>&1 || ffmpeg -y -i \"$file\" -vframes 1 \"$frame\" >/dev/null 2>&1; fi";
        } else {
            script = "file=\"$1\"; mon=\"$2\"; pdir=\"$3\"; " + "mkdir -p \"$pdir\" 2>/dev/null; " + "pkill -f \"input-ipc-server=/tmp/aeonshell-mpv-${mon}.sock\" 2>/dev/null; " + "rm -f \"/tmp/aeonshell-video-wp/$mon\" 2>/dev/null; " + "printf 'image|%s\\n' \"$file\" > \"$pdir/$mon\"; " + "pgrep -x awww-daemon >/dev/null 2>&1 || { awww-daemon >/tmp/awww-daemon.log 2>&1 & disown; sleep 0.4; }; " + "awww img \"$file\" -o \"$mon\" --transition-type wipe --transition-fps 60 --transition-duration 0.7 >/tmp/awww-apply.log 2>&1";
        }

        wallpaperApplyProc.command = ["sh", "-c", script, "sh", path, targetMon, root.persistStateDir, frameFile];
        wallpaperApplyProc.running = true;
    }

    function applyRandomWallpaper() {
        if (randomWallpaperProc.running)
            randomWallpaperProc.running = false;
        randomWallpaperProc.command = ["sh", "-c", "mkdir -p \"$1\" 2>/dev/null; find \"$1\" -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null | grep -Ei '\\.(jpg|jpeg|png|webp|bmp|gif|mp4|webm|mkv|avi|mov|m4v)$'", "sh", AppSettings.wallpaperDir];
        randomWallpaperProc.running = true;
    }

    function generateMissingThumbs() {
        const videos = root.wallpaperFiles.filter(f => root.isVideoFile(f));
        if (videos.length === 0)
            return;
        if (wallpaperThumbProc.running)
            wallpaperThumbProc.running = false;

        const script = "td=\"$1\"; d=\"$2\"; shift 2; mkdir -p \"$td\" 2>/dev/null; " + "printf '%s\\0' \"$@\" | xargs -0 -P 4 -I{} sh -c '" + "thumb=\"$1/{}.jpg\"; " + "[ -f \"$thumb\" ] || { ffmpeg -y -ss 00:00:01 -i \"$2/{}\" -frames:v 1 -vf scale=360:-1 -q:v 4 \"$thumb\" >>/tmp/aeonshell-thumbs.log 2>&1 && echo 1; }" + "' _ \"$td\" \"$d\"";

        wallpaperThumbProc.command = ["sh", "-c", script, "sh", root.thumbCacheDir, AppSettings.wallpaperDir].concat(videos);
        wallpaperThumbProc.running = true;
    }

    Process {
        id: wallpaperApplyProc
        onExited: {
            MpvFullscreenWatcher.registerVideoWallpaper(root._activeApplyMon, root._activeApplyIsVideo ? root._activeApplyPath : "");
            if (root._activeApplyUpdateColors) {
                if (root._activeApplyIsVideo && root._activeFrameFile) {
                    const tmpFrame = root._activeFrameFile;
                    Colors.applyThemeFromImage(tmpFrame, () => {
                        Quickshell.execDetached(["rm", "-f", tmpFrame]);
                    });
                } else {
                    Colors.applyThemeFromImage(root._activeApplyPath, null);
                }
            }
            root._applyingWallpaper = false;
            if (root._queuedWallpaperPath !== "") {
                const next = root._queuedWallpaperPath;
                root._queuedWallpaperPath = "";
                root.applyWallpaper(next);
            }
        }
    }

    Process {
        id: randomWallpaperProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
                if (lines.length === 0)
                    return;
                const pick = lines[Math.floor(Math.random() * lines.length)];
                root.applyWallpaper(AppSettings.wallpaperDir + "/" + pick);
            }
        }
    }

    Process {
        id: wallpaperListProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
                root.wallpaperFiles = lines;
                root.generateMissingThumbs();
            }
        }
    }

    Process {
        id: wallpaperThumbProc
        property bool createdAny: false
        stdout: StdioCollector {
            onStreamFinished: wallpaperThumbProc.createdAny = this.text.indexOf("1") !== -1
        }
        onExited: {
            if (wallpaperThumbProc.createdAny)
                root.thumbGenTick++;
            wallpaperThumbProc.createdAny = false;
        }
    }

    readonly property bool commandMode: searchText.startsWith(">")
    readonly property string commandQuery: commandMode ? searchText.slice(1).trim().toLowerCase() : ""

    readonly property var availableCommands: [
        {
            id: "wallpaper",
            label: "Wallpaper",
            desc: "Browse and set a desktop wallpaper",
            icon: "󰈟"
        },
        {
            id: "random-wallpaper",
            label: "Random wallpaper",
            desc: "Pick and apply a random one from your folder",
            icon: "󰒝"
        },
        {
            id: "settings",
            label: "Settings",
            desc: "Open aeonshell settings",
            icon: "󰒓"
        },
        {
            id: "settings-launcher",
            label: "Settings → Launcher",
            desc: "Jump to launcher & wallpaper settings",
            icon: "󰀻"
        },
        {
            id: "settings-behavior",
            label: "Settings → Notifications & Media",
            desc: "Jump to notifications and media behavior",
            icon: "󰂚"
        },
        {
            id: "settings-about",
            label: "Settings → System & About",
            desc: "Jump to storage, reset, and about",
            icon: "󰋼"
        },
        {
            id: "reload",
            label: "Reload Hyprland",
            desc: "hyprctl reload — reapply config changes",
            icon: "󰜉"
        },
        {
            id: "hidden-apps",
            label: "Hidden apps",
            desc: "Show apps hidden from the launcher, click to restore",
            icon: "󰈈"
        }
    ]

    readonly property var filteredCommands: {
        if (!commandMode)
            return [];
        if (commandQuery === "")
            return availableCommands;
        return availableCommands.filter(c => c.id.indexOf(commandQuery) !== -1 || c.label.toLowerCase().indexOf(commandQuery) !== -1);
    }

    function activateSelectedCommand() {
        if (commandSelectedIndex < 0 || commandSelectedIndex >= filteredCommands.length)
            return;
        const cmd = filteredCommands[commandSelectedIndex];

        if (cmd.id === "wallpaper") {
            openWallpaperPicker();
            return;
        }
        if (cmd.id === "hidden-apps") {
            root.searchText = "";
            root.hiddenAppsMode = true;
            if (root.winItem)
                root.winItem.focusSearch();
            return;
        }
        if (cmd.id === "random-wallpaper") {
            applyRandomWallpaper();
            root.open = false;
            return;
        }
        if (cmd.id === "reload") {
            Quickshell.execDetached(["hyprctl", "reload"]);
            root.open = false;
            return;
        }
        if (cmd.id === "settings" || cmd.id.startsWith("settings-")) {
            ShellState.settingsSection = cmd.id === "settings" ? "panel" : cmd.id.slice("settings-".length);
            ShellState.settingsWindowOpen = true;
            root.open = false;
            return;
        }
    }

    readonly property var allApps: {
        let list = [...DesktopEntries.applications.values];
        list = list.filter(a => a && a.name && !a.noDisplay && !AppSettings.isAppHidden(a.id));
        list.sort((a, b) => a.name.localeCompare(b.name));
        return list;
    }

    readonly property var hiddenApps: {
        let list = [...DesktopEntries.applications.values];
        list = list.filter(a => a && a.name && !a.noDisplay && AppSettings.isAppHidden(a.id));
        list.sort((a, b) => a.name.localeCompare(b.name));
        return list;
    }

    readonly property var appsById: {
        let m = Object.create(null);
        for (const a of allApps)
            m[a.id] = a;
        return m;
    }

    readonly property var recentApps: {
        let list = [];
        for (const id of launcherSettings.recentIds) {
            const a = appsById[id];
            if (a)
                list.push(a);
        }
        return list;
    }

    readonly property var filteredApps: {
        const q = searchText.trim().toLowerCase();
        if (q === "" || commandMode)
            return allApps;

        let scored = [];
        for (const a of allApps) {
            const name = (a.name || "").toLowerCase();
            const comment = (a.comment || "").toLowerCase();
            const keywords = ((a.keywords || []).join(" ")).toLowerCase();
            const categories = ((a.categories || []).join(" ")).toLowerCase();
            let score = -1;
            if (name === q)
                score = 100;
            else if (name.startsWith(q))
                score = 90;
            else if (name.split(" ").some(w => w.startsWith(q)))
                score = 75;
            else if (name.includes(q))
                score = 60;
            else if (keywords.includes(q))
                score = 45;
            else if (comment.includes(q))
                score = 30;
            else if (categories.includes(q))
                score = 15;
            if (score >= 0)
                scored.push({
                    app: a,
                    score: score
                });
        }
        scored.sort((x, y) => (y.score - x.score) || x.app.name.localeCompare(y.app.name));
        return scored.map(s => s.app);
    }

    readonly property var gridApps: hiddenAppsMode ? hiddenApps : (searchText.trim() === "" ? allApps : filteredApps)

    readonly property var flatModel: {
        let fm = [];
        if (hiddenAppsMode) {
            if (hiddenApps.length > 0) {
                fm.push({
                    kind: "header",
                    label: "Hidden apps — click to restore",
                    clearable: false
                });
                for (const a of hiddenApps)
                    fm.push({
                        kind: "app",
                        app: a
                    });
            }
            return fm;
        }
        if (searchText.trim() === "") {
            if (recentApps.length > 0) {
                fm.push({
                    kind: "header",
                    label: "Recently used",
                    clearable: true
                });
                for (const a of recentApps)
                    fm.push({
                        kind: "app",
                        app: a
                    });
            }
            const recentSet = new Set(recentApps.map(a => a.id));
            const rest = allApps.filter(a => !recentSet.has(a.id));
            if (rest.length > 0) {
                fm.push({
                    kind: "header",
                    label: "All applications",
                    clearable: false
                });
                for (const a of rest)
                    fm.push({
                        kind: "app",
                        app: a
                    });
            }
        } else {
            for (const a of filteredApps)
                fm.push({
                    kind: "app",
                    app: a
                });
        }
        return fm;
    }

    readonly property var appPositions: {
        let positions = [];
        for (let i = 0; i < flatModel.length; i++) {
            if (flatModel[i].kind === "app")
                positions.push(i);
        }
        return positions;
    }

    function launchApp(app) {
        if (!app)
            return;
        root.trackLaunch(app);
        app.execute();
        root.open = false;
    }

    function launchSelected() {
        if (root.gridView) {
            if (selectedIndex < 0 || selectedIndex >= gridApps.length)
                return;
            root.launchApp(gridApps[selectedIndex]);
            return;
        }
        if (selectedIndex < 0 || selectedIndex >= appPositions.length)
            return;
        const entry = flatModel[appPositions[selectedIndex]];
        if (entry && entry.app)
            root.launchApp(entry.app);
    }

    function restoreSelected() {
        if (!root.hiddenAppsMode)
            return;
        if (root.gridView) {
            if (selectedIndex < 0 || selectedIndex >= gridApps.length)
                return;
            AppSettings.toggleAppHidden(gridApps[selectedIndex].id);
            return;
        }
        if (selectedIndex < 0 || selectedIndex >= appPositions.length)
            return;
        const entry = flatModel[appPositions[selectedIndex]];
        if (entry && entry.app)
            AppSettings.toggleAppHidden(entry.app.id);
    }

    LazyLoader {
        id: winLoader
        active: root.open || hideTimer.running

        PanelWindow {
            id: launcher

            property bool _animReady: false
            readonly property var appsView: launcher.appsView
            readonly property var commandsView: launcher.commandsView
            readonly property bool visualOpen: root.open && _animReady

            function focusSearch() {
                Qt.callLater(() => searchInput.forceActiveFocus());
            }

            function resetListScroll() {
                if (launcher.appsView)
                    launcher.appsView.positionViewAtIndex(0, ListView.Contain);
            }

            screen: root.activeScreen
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            exclusiveZone: 0
            color: "transparent"
            visible: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: root.open ? null : emptyMask
            Region {
                id: emptyMask
            }

            Component.onCompleted: {
                Qt.callLater(() => {
                    launcher._animReady = true;
                    searchInput.forceActiveFocus();
                });
            }

            Shortcut {
                sequence: "Escape"
                enabled: root.open
                onActivated: {
                    if (root.wallpaperPickerOpen) {
                        root.closeWallpaperPicker();
                    } else if (root.hiddenAppsMode) {
                        root.hiddenAppsMode = false;
                        searchInput.forceActiveFocus();
                    } else if (root.commandMode) {
                        root.searchText = "";
                        searchInput.forceActiveFocus();
                    } else {
                        root.open = false;
                    }
                }
            }

            Connections {
                target: root
                function onSearchTextChanged() {
                    if (root.hiddenAppsMode && root.searchText !== "")
                        root.hiddenAppsMode = false;
                    root.selectedIndex = 0;
                    root.commandSelectedIndex = 0;
                    if (launcher.appsView)
                        launcher.appsView.positionViewAtIndex(0, ListView.Contain);
                }
                function onCommandSelectedIndexChanged() {
                    if (launcher.commandsView && root.commandSelectedIndex >= 0)
                        launcher.commandsView.positionViewAtIndex(root.commandSelectedIndex, ListView.Contain);
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: if (root.open)
                    root.open = false
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
                width: root.wallpaperPickerOpen ? 780 : 700
                height: root.wallpaperPickerOpen ? 340 : 640
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 36
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on width {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutQuad
                    }
                }

                radius: 28
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, AppSettings.popupOpacity)
                border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
                border.width: 1
                clip: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: searchInput.forceActiveFocus()
                }

                transformOrigin: Item.Bottom
                scale: launcher.visualOpen ? 1.0 : 0.9
                opacity: launcher.visualOpen ? 1.0 : 0.0
                y: launcher.visualOpen ? 0 : 44

                Behavior on scale {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.15
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.15
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.28
                    height: 3
                    visible: !root.wallpaperPickerOpen

                    radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.0)
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.85)
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.0)
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.contentPadding
                    anchors.topMargin: root.wallpaperPickerOpen ? 8 : root.contentPadding + 12
                    spacing: root.wallpaperPickerOpen ? 6 : 14

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.wallpaperPickerOpen ? 0 : 48
                        opacity: root.wallpaperPickerOpen ? 0 : 1
                        clip: true

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.InOutQuad
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.InOutQuad
                            }
                        }

                        radius: 24
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                        border.color: searchInput.activeFocus && (!root.wallpaperPickerOpen || root.wpFocusSection === 0) ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4) : "transparent"
                        border.width: 1
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.contentPadding
                            anchors.rightMargin: root.contentPadding
                            spacing: 10

                            Text {
                                id: searchIcon
                                Layout.alignment: Qt.AlignVCenter
                                text: "󰍉"
                                font.pixelSize: 16
                                color: searchInput.activeFocus && (!root.wallpaperPickerOpen || root.wpFocusSection === 0) ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)

                                scale: root.searchText.length > 0 ? 1.1 : 1.0
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutBack
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            TextField {
                                id: searchInput
                                Layout.fillWidth: true
                                readOnly: root.wallpaperPickerOpen

                                placeholderText: root.wallpaperPickerOpen ? "Esc to go back" : (root.commandMode ? "Type a command…" : "Search applications...")
                                placeholderTextColor: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                                text: root.searchText

                                onTextChanged: root.searchText = text

                                font.pixelSize: 17
                                color: Colors.surfaceText
                                background: Item {}

                                leftPadding: 0
                                topPadding: 0
                                bottomPadding: 0

                                Keys.onLeftPressed: event => {
                                    if (!root.wallpaperPickerOpen && root.gridView && !root.commandMode) {
                                        if (root.gridApps.length === 0 || !launcher.appsGrid)
                                            return;
                                        launcher.appsGrid.moveCurrentIndexLeft();
                                        root.selectedIndex = launcher.appsGrid.currentIndex;
                                        return;
                                    }
                                    if (!root.wallpaperPickerOpen || root.wallpaperFiles.length === 0) {
                                        event.accepted = false;
                                        return;
                                    }

                                    event.accepted = true;
                                    if (root.wpFocusSection === 0) {
                                        const screens = Quickshell.screens;
                                        let idx = screens.findIndex(s => s.name === root.targetScreenName);
                                        if (idx > 0)
                                            root.targetScreenName = screens[idx - 1].name;
                                        else
                                            root.targetScreenName = screens[screens.length - 1].name;
                                    } else if (root.wpFocusSection === 1) {
                                        const n = root.wallpaperFiles.length;
                                        root.wallpaperIndex = (root.wallpaperIndex - 1 + n) % n;
                                    }
                                }

                                Keys.onRightPressed: event => {
                                    if (!root.wallpaperPickerOpen && root.gridView && !root.commandMode) {
                                        if (root.gridApps.length === 0 || !launcher.appsGrid)
                                            return;
                                        launcher.appsGrid.moveCurrentIndexRight();
                                        root.selectedIndex = launcher.appsGrid.currentIndex;
                                        return;
                                    }
                                    if (!root.wallpaperPickerOpen || root.wallpaperFiles.length === 0) {
                                        event.accepted = false;
                                        return;
                                    }

                                    event.accepted = true;
                                    if (root.wpFocusSection === 0) {
                                        const screens = Quickshell.screens;
                                        let idx = screens.findIndex(s => s.name === root.targetScreenName);
                                        if (idx < screens.length - 1)
                                            root.targetScreenName = screens[idx + 1].name;
                                        else
                                            root.targetScreenName = screens[0].name;
                                    } else if (root.wpFocusSection === 1) {
                                        const n = root.wallpaperFiles.length;
                                        root.wallpaperIndex = (root.wallpaperIndex + 1) % n;
                                    }
                                }

                                Keys.onUpPressed: event => {
                                    if (root.wallpaperPickerOpen) {
                                        if (root.wpFocusSection === 1)
                                            root.wpFocusSection = 0;
                                        event.accepted = true;
                                        return;
                                    }
                                    if (root.commandMode) {
                                        if (root.filteredCommands.length === 0)
                                            return;
                                        root.commandSelectedIndex = Math.max(0, root.commandSelectedIndex - 1);
                                        return;
                                    }
                                    if (root.gridView) {
                                        if (root.gridApps.length === 0 || !launcher.appsGrid)
                                            return;
                                        launcher.appsGrid.moveCurrentIndexUp();
                                        root.selectedIndex = launcher.appsGrid.currentIndex;
                                        return;
                                    }
                                    if (root.appPositions.length === 0 || !launcher.appsView)
                                        return;
                                    root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                                    launcher.appsView.positionViewAtIndex(root.selectedIndex === 0 ? 0 : root.appPositions[root.selectedIndex], ListView.Contain);
                                }

                                Keys.onDownPressed: event => {
                                    if (root.wallpaperPickerOpen) {
                                        if (root.wpFocusSection === 0)
                                            root.wpFocusSection = 1;
                                        event.accepted = true;
                                        return;
                                    }
                                    if (root.commandMode) {
                                        if (root.filteredCommands.length === 0)
                                            return;
                                        root.commandSelectedIndex = Math.min(root.filteredCommands.length - 1, root.commandSelectedIndex + 1);
                                        return;
                                    }
                                    if (root.gridView) {
                                        if (root.gridApps.length === 0 || !launcher.appsGrid)
                                            return;
                                        launcher.appsGrid.moveCurrentIndexDown();
                                        root.selectedIndex = launcher.appsGrid.currentIndex;
                                        return;
                                    }
                                    if (root.appPositions.length === 0 || !launcher.appsView)
                                        return;
                                    root.selectedIndex = Math.min(root.appPositions.length - 1, root.selectedIndex + 1);
                                    launcher.appsView.positionViewAtIndex(root.appPositions[root.selectedIndex], ListView.Contain);
                                }

                                Keys.onReturnPressed: event => {
                                    if (root.wallpaperPickerOpen) {
                                        if (root.wallpaperFiles.length === 0)
                                            return;
                                        root.applyWallpaper(AppSettings.wallpaperDir + "/" + root.wallpaperFiles[root.wallpaperIndex]);
                                        event.accepted = true;
                                        return;
                                    }
                                    if (root.commandMode) {
                                        root.activateSelectedCommand();
                                        return;
                                    }
                                    root.launchSelected();
                                }

                                Keys.onPressed: event => {
                                    if (root.hiddenAppsMode && searchInput.text === "" && (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)) {
                                        root.restoreSelected();
                                        event.accepted = true;
                                    }
                                }
                            }

                            Text {
                                visible: root.searchText.length > 0
                                text: "󰅖"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                                font.pixelSize: 14
                                TapHandler {
                                    onTapped: {
                                        root.searchText = "";
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }

                            Rectangle {
                                id: hiddenToggleBtn
                                visible: !root.wallpaperPickerOpen
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                Layout.alignment: Qt.AlignVCenter
                                radius: 10
                                color: root.hiddenAppsMode ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.22) : (hiddenToggleHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.10) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.055))
                                border.color: root.hiddenAppsMode ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4) : "transparent"
                                border.width: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰈈"
                                    font.pixelSize: 17
                                    color: root.hiddenAppsMode ? Colors.primary : Colors.surfaceText
                                    opacity: root.hiddenAppsMode ? 1.0 : (root.hiddenApps.length > 0 ? 0.75 : 0.4)
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 120
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: hiddenToggleHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: {
                                        root.searchText = "";
                                        root.hiddenAppsMode = !root.hiddenAppsMode;
                                        root.selectedIndex = 0;
                                        searchInput.forceActiveFocus();
                                    }
                                }

                                ToolTip.visible: hiddenToggleHover.hovered
                                ToolTip.delay: 400
                                ToolTip.text: root.hiddenAppsMode ? "Show all apps" : "Hidden apps (" + root.hiddenApps.length + ")"
                            }

                            Rectangle {
                                id: viewModeBtn
                                visible: !root.wallpaperPickerOpen
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                Layout.alignment: Qt.AlignVCenter
                                radius: 10
                                color: viewModeHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.10) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.055)
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.gridView ? "▦" : "☰"
                                    font.pixelSize: 15
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.75)
                                }

                                HoverHandler {
                                    id: viewModeHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: {
                                        AppSettings.launcherViewMode = root.gridView ? "list" : "grid";
                                        root.selectedIndex = 0;
                                        searchInput.forceActiveFocus();
                                    }
                                }

                                ToolTip.visible: viewModeHover.hovered
                                ToolTip.delay: 400
                                ToolTip.text: root.gridView ? "List view" : "Grid view"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.wallpaperPickerOpen ? 0 : 1
                        Layout.topMargin: root.wallpaperPickerOpen ? -14 : 0
                        opacity: root.wallpaperPickerOpen ? 0 : 1
                        clip: true
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.InOutQuad
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.InOutQuad
                            }
                        }
                        Behavior on Layout.topMargin {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    Item {
                        id: listWrap
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: -8
                        Layout.rightMargin: -8
                        clip: true

                        Loader {
                            id: appsListLoader
                            anchors.fill: parent
                            active: !root.gridView && !root.commandMode && !root.wallpaperPickerOpen
                            visible: active
                            sourceComponent: appsListComp
                        }

                        Loader {
                            id: appGridLoader
                            anchors.fill: parent
                            active: root.gridView && !root.commandMode && !root.wallpaperPickerOpen
                            visible: active
                            sourceComponent: appGridComp
                        }

                        Loader {
                            id: commandsListLoader
                            anchors.fill: parent
                            active: root.commandMode && !root.wallpaperPickerOpen
                            visible: active
                            sourceComponent: commandsListComp
                        }

                        Loader {
                            id: wallpaperPickerLoader
                            anchors.fill: parent
                            active: root.wallpaperPickerOpen
                            visible: active
                            sourceComponent: wallpaperPickerComp
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Text {
                            text: root.wallpaperPickerOpen ? "↑ ↓  Select Section" : (root.gridView && !root.commandMode ? "↑↓← →  Navigate" : "↑ ↓  Navigate")
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                            font.pixelSize: 11
                        }
                        Text {
                            text: root.wallpaperPickerOpen ? "← →  Choose" : "↵  Open"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                            font.pixelSize: 11
                        }
                        Text {
                            text: root.wallpaperPickerOpen ? "↵  Apply" : ""
                            visible: root.wallpaperPickerOpen
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                            font.pixelSize: 11
                        }
                        Text {
                            text: "RMB  Hide"
                            visible: !root.wallpaperPickerOpen && !root.commandMode && !root.hiddenAppsMode
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                            font.pixelSize: 11
                        }
                        Text {
                            text: "⌫  Restore"
                            visible: root.hiddenAppsMode
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                            font.pixelSize: 11
                        }
                        Text {
                            text: "Esc  " + ((root.wallpaperPickerOpen || root.commandMode || root.hiddenAppsMode) ? "Back" : "Close")
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                            font.pixelSize: 11
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.wallpaperPickerOpen ? (root.wallpaperFiles.length + " wallpapers") : (root.commandMode ? (root.filteredCommands.length + " commands") : (root.hiddenAppsMode ? (root.hiddenApps.length + " hidden") : (root.appPositions.length + " applications")))
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    Component {
        id: appsListComp
        ListView {
            id: appsList
            clip: true
            spacing: root.listSpacing
            model: root.flatModel

            currentIndex: (root.selectedIndex >= 0 && root.selectedIndex < root.appPositions.length) ? root.appPositions[root.selectedIndex] : -1

            onCountChanged: {
                if (root.selectedIndex >= root.appPositions.length)
                    root.selectedIndex = Math.max(0, root.appPositions.length - 1);
            }

            delegate: Item {
                id: rowRoot
                required property var modelData
                required property int index
                width: ListView.view.width

                readonly property string rowKind: modelData ? modelData.kind : ""
                readonly property var rowApp: (modelData && modelData.app) ? modelData.app : null

                height: rowKind === "header" ? root.headerHeight : root.appHeight

                readonly property int myAppIndex: rowKind === "app" ? root.appPositions.indexOf(index) : -1
                readonly property bool isCurrent: myAppIndex !== -1 && myAppIndex === root.selectedIndex

                RowLayout {
                    visible: rowRoot.rowKind === "header"
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                        text: rowRoot.rowKind === "header" ? (rowRoot.modelData.label || "") : ""
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                        font.pixelSize: 12
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: rowRoot.rowKind === "header" && !!rowRoot.modelData.clearable
                        text: "Clear"
                        color: clearHover.hovered ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                        font.pixelSize: 12
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }

                        HoverHandler {
                            id: clearHover
                        }
                        TapHandler {
                            onTapped: root.clearRecent()
                        }
                    }
                }

                Rectangle {
                    visible: rowRoot.rowKind === "app"
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    radius: 12

                    color: rowRoot.isCurrent ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14) : (hover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent")
                    border.color: rowRoot.isCurrent ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : "transparent"
                    border.width: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 130
                        }
                    }

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
                                source: rowRoot.rowApp ? Quickshell.iconPath(rowRoot.rowApp.icon, true) : ""
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: rowRoot.rowApp ? (rowRoot.rowApp.name || "") : ""
                                color: Colors.surfaceText
                                font.pixelSize: 15
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: !!(rowRoot.rowApp && rowRoot.rowApp.comment)
                                text: (rowRoot.rowApp && rowRoot.rowApp.comment) ? rowRoot.rowApp.comment : ""
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            visible: rowRoot.rowKind === "app" && root.hiddenAppsMode
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: restoreHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "↺"
                                font.pixelSize: 15
                                color: restoreHover.hovered ? Colors.primary : Colors.surfaceText
                            }

                            HoverHandler {
                                id: restoreHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: if (rowRoot.rowApp)
                                    AppSettings.toggleAppHidden(rowRoot.rowApp.id)
                            }

                            ToolTip.visible: restoreHover.hovered
                            ToolTip.delay: 400
                            ToolTip.text: "Restore to list"
                        }
                    }

                    HoverHandler {
                        id: hover
                        onHoveredChanged: {
                            if (hovered && rowRoot.myAppIndex !== -1)
                                root.selectedIndex = rowRoot.myAppIndex;
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: if (rowRoot.rowApp)
                            root.launchApp(rowRoot.rowApp)
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            if (!rowRoot.rowApp || root.hiddenAppsMode)
                                return;
                            AppSettings.toggleAppHidden(rowRoot.rowApp.id);
                        }
                    }
                }
            }

            Text {
                visible: root.flatModel.length === 0
                anchors.centerIn: parent
                text: root.hiddenAppsMode ? "No hidden apps" : "No applications found"
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                font.pixelSize: 15
            }
        }
    }

    Component {
        id: appGridComp
        GridView {
            id: appGridView
            clip: true
            readonly property int minCellWidth: 116
            readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))
            cellWidth: width / columns
            cellHeight: 128
            model: root.gridApps
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 120
            highlight: Item {}

            onCurrentIndexChanged: {
                if (root.selectedIndex !== currentIndex)
                    root.selectedIndex = currentIndex;
            }

            Connections {
                target: root
                function onSelectedIndexChanged() {
                    if (appGridView.currentIndex !== root.selectedIndex)
                        appGridView.currentIndex = root.selectedIndex;
                }
                function onGridAppsChanged() {
                    if (appGridView.currentIndex >= root.gridApps.length)
                        appGridView.currentIndex = Math.max(0, root.gridApps.length - 1);
                }
            }

            delegate: Item {
                id: tileRoot
                required property var modelData
                required property int index
                width: appGridView.cellWidth
                height: appGridView.cellHeight

                readonly property bool isCurrent: tileRoot.index === root.selectedIndex

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 14
                    color: tileRoot.isCurrent ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14) : (tileHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent")
                    border.color: tileRoot.isCurrent ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : "transparent"
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 130
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 8

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 60
                            radius: 16
                            color: tileRoot.isCurrent ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.10)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 130
                                }
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 40
                                source: tileRoot.modelData ? Quickshell.iconPath(tileRoot.modelData.icon, true) : ""
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignTop
                            text: tileRoot.modelData ? (tileRoot.modelData.name || "") : ""
                            color: Colors.surfaceText
                            opacity: 0.92
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }
                    }

                    HoverHandler {
                        id: tileHover
                        onHoveredChanged: if (hovered)
                            root.selectedIndex = tileRoot.index
                    }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: if (tileRoot.modelData)
                            root.launchApp(tileRoot.modelData)
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            if (!tileRoot.modelData || root.hiddenAppsMode)
                                return;
                            AppSettings.toggleAppHidden(tileRoot.modelData.id);
                        }
                    }

                    Rectangle {
                        visible: root.hiddenAppsMode
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 22
                        height: 22
                        radius: 11
                        color: restoreTileHover.hovered ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12)
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "↺"
                            font.pixelSize: 12
                            color: restoreTileHover.hovered ? Colors.primary : Colors.surfaceText
                        }

                        HoverHandler {
                            id: restoreTileHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: if (tileRoot.modelData)
                                AppSettings.toggleAppHidden(tileRoot.modelData.id)
                        }

                        ToolTip.visible: restoreTileHover.hovered
                        ToolTip.delay: 400
                        ToolTip.text: "Restore to list"
                    }
                }
            }

            Text {
                visible: root.gridApps.length === 0
                anchors.centerIn: parent
                text: root.hiddenAppsMode ? "No hidden apps" : "No applications found"
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                font.pixelSize: 15
            }
        }
    }

    Component {
        id: commandsListComp
        ListView {
            id: commandsList
            clip: true
            spacing: root.listSpacing
            model: root.filteredCommands
            currentIndex: root.commandSelectedIndex

            delegate: Item {
                id: cmdDelegate
                required property var modelData
                required property int index
                width: ListView.view.width
                height: root.appHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    radius: 12
                    color: cmdDelegate.index === root.commandSelectedIndex ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14) : (cmdHover.hovered ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent")
                    border.color: cmdDelegate.index === root.commandSelectedIndex ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : "transparent"
                    border.width: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 130
                        }
                    }

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
                                text: cmdDelegate.modelData ? cmdDelegate.modelData.icon : ""
                                color: Colors.primary
                                font.pixelSize: 18
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: cmdDelegate.modelData ? cmdDelegate.modelData.label : ""
                                color: Colors.surfaceText
                                font.pixelSize: 15
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: cmdDelegate.modelData ? cmdDelegate.modelData.desc : ""
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    HoverHandler {
                        id: cmdHover
                        onHoveredChanged: if (hovered)
                            root.commandSelectedIndex = cmdDelegate.index
                    }
                    TapHandler {
                        onTapped: {
                            root.commandSelectedIndex = cmdDelegate.index;
                            root.activateSelectedCommand();
                        }
                    }
                }
            }

            Text {
                visible: root.filteredCommands.length === 0
                anchors.centerIn: parent
                text: "No matching commands"
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                font.pixelSize: 15
            }
        }
    }

    Component {
        id: wallpaperPickerComp
        ColumnLayout {
            id: wallpaperPickerView
            spacing: 6

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.wallpaperFiles.length === 0 ? "No wallpapers found in " + AppSettings.wallpaperDir : "Select Monitor & Wallpaper"
                    color: root.wpFocusSection === 0 ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    font.pixelSize: 12
                    font.bold: true
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.wallpaperFiles.length > 0
                    spacing: 8

                    Repeater {
                        model: Quickshell.screens
                        delegate: Rectangle {
                            id: monChip
                            required property var modelData
                            readonly property bool isPrim: root.isScreenPrimary(monChip.modelData)
                            readonly property bool isSel: root.targetScreenName === monChip.modelData.name

                            implicitWidth: monLayout.implicitWidth + 20
                            implicitHeight: 28
                            radius: 7
                            color: monChip.isSel ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2) : (monHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                            border.color: (monChip.isSel || (root.wpFocusSection === 0 && monHover.hovered)) ? Colors.primary : Qt.rgba(1, 1, 1, 0.1)
                            border.width: monChip.isSel ? 2 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            RowLayout {
                                id: monLayout
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "󰍹"
                                    font.pixelSize: 12
                                    color: monChip.isSel ? Colors.primary : Colors.surfaceText
                                }
                                Text {
                                    text: monChip.modelData.name + (monChip.isPrim ? " (Colors)" : " (Image only)")
                                    font.pixelSize: 11
                                    font.bold: monChip.isSel
                                    color: monChip.isSel ? Colors.primary : Colors.surfaceText
                                }
                            }

                            HoverHandler {
                                id: monHover
                            }
                            TapHandler {
                                onTapped: {
                                    root.targetScreenName = monChip.modelData.name;
                                    root.wpFocusSection = 0;
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: -root.contentPadding
                Layout.rightMargin: -root.contentPadding
                Layout.topMargin: -2
                clip: true

                PathView {
                    id: wallpaperStrip
                    anchors.centerIn: parent
                    width: parent.width
                    height: 180
                    model: root.wallpaperFiles
                    pathItemCount: Math.min(5, Math.max(1, root.wallpaperFiles.length))
                    interactive: true
                    snapMode: PathView.SnapToItem
                    flickDeceleration: 2000
                    highlightMoveDuration: 260

                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5

                    Component.onCompleted: currentIndex = root.wallpaperIndex
                    onCurrentIndexChanged: if (root.wallpaperIndex !== currentIndex)
                        root.wallpaperIndex = currentIndex

                    Connections {
                        target: root
                        function onWallpaperIndexChanged() {
                            if (wallpaperStrip.currentIndex !== root.wallpaperIndex)
                                wallpaperStrip.currentIndex = root.wallpaperIndex;
                        }
                    }

                    readonly property int cardWidth: 240
                    readonly property int cardHeight: 150

                    path: Path {
                        startX: -wallpaperStrip.cardWidth * 0.8
                        startY: wallpaperStrip.height / 2

                        PathAttribute {
                            name: "itemScale"
                            value: 0.7
                        }
                        PathAttribute {
                            name: "itemOpacity"
                            value: 0.3
                        }
                        PathAttribute {
                            name: "itemZ"
                            value: 0
                        }

                        PathLine {
                            x: wallpaperStrip.width / 2
                            y: wallpaperStrip.height / 2
                        }

                        PathAttribute {
                            name: "itemScale"
                            value: 1.0
                        }
                        PathAttribute {
                            name: "itemOpacity"
                            value: 1.0
                        }
                        PathAttribute {
                            name: "itemZ"
                            value: 10
                        }

                        PathLine {
                            x: wallpaperStrip.width + wallpaperStrip.cardWidth * 0.8
                            y: wallpaperStrip.height / 2
                        }

                        PathAttribute {
                            name: "itemScale"
                            value: 0.7
                        }
                        PathAttribute {
                            name: "itemOpacity"
                            value: 0.3
                        }
                        PathAttribute {
                            name: "itemZ"
                            value: 0
                        }
                    }

                    delegate: Item {
                        id: wpDelegate
                        required property string modelData
                        required property int index
                        width: wallpaperStrip.cardWidth
                        height: wallpaperStrip.cardHeight
                        scale: PathView.itemScale
                        opacity: PathView.itemOpacity
                        z: PathView.itemZ

                        readonly property bool isCurrent: PathView.itemScale > 0.95
                        readonly property bool isVideo: root.isVideoFile(modelData)

                        readonly property string imgSource: wpDelegate.isVideo ? ("file://" + root.thumbCacheDir + "/" + modelData + ".jpg?g=" + root.thumbGenTick) : ("file://" + AppSettings.wallpaperDir + "/" + modelData)

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
                                    text: wpDelegate.modelData
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
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: "transparent"
                            border.color: wpDelegate.isCurrent ? Colors.primary : Qt.rgba(0.55, 0.55, 0.55, 0.4)
                            border.width: wpDelegate.isCurrent ? 3 : 1.5
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 180
                                }
                            }
                            Behavior on border.width {
                                NumberAnimation {
                                    duration: 180
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.wpFocusSection = 1;
                                if (wpDelegate.isCurrent) {
                                    root.applyWallpaper(AppSettings.wallpaperDir + "/" + wpDelegate.modelData);
                                } else {
                                    root.wallpaperIndex = wpDelegate.index;
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: root.contentPadding
                    anchors.verticalCenter: wallpaperStrip.verticalCenter
                    text: "‹"
                    font.pixelSize: 24
                    color: root.wpFocusSection === 1 ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                    visible: root.wallpaperFiles.length > 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: root.contentPadding
                    anchors.verticalCenter: wallpaperStrip.verticalCenter
                    text: "›"
                    font.pixelSize: 24
                    color: root.wpFocusSection === 1 ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.25)
                    visible: root.wallpaperFiles.length > 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }

            Text {
                visible: root.wallpaperFiles.length > 0
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 2
                text: (root.wallpaperIndex + 1) + " / " + root.wallpaperFiles.length
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                font.pixelSize: 11
            }
        }
    }
}
