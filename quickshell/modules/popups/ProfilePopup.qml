// ProfilePopup.qml

import "../"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

PopupWindow {
    id: popup

    property bool open: false
    property bool _animReady: false
    readonly property bool visualOpen: popup.open && popup._animReady
    readonly property bool isHovered: hover.hovered
    readonly property bool keepOpen: (avatarPickerLoader.item && avatarPickerLoader.item.visible) || (weatherInputLoader.item && weatherInputLoader.item.visible)

    property string username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
    property string hostname: "..."
    property string kernelRaw: ""
    property bool kernelLoaded: false
    readonly property string kernel: !popup.kernelLoaded ? "..." : (popup.kernelRaw || Lang.t("common.unknown"))
    property int uptimeSeconds: -1
    readonly property string uptime: {
        if (popup.uptimeSeconds < 0)
            return "...";
        const sec = popup.uptimeSeconds;
        const d = Math.floor(sec / 86400);
        const h = Math.floor((sec % 86400) / 3600);
        const m = Math.floor((sec % 3600) / 60);
        return (d > 0 ? d + Lang.t("unit.d") + " " : "") + (h > 0 ? h + Lang.t("unit.h") + " " : "") + m + Lang.t("unit.min");
    }
    property string installDateStr: ShellState.cachedInstallDate
    property bool installDateLoaded: ShellState.cachedInstallDate !== ""
    readonly property string installAge: !popup.installDateLoaded ? "..." : (popup.installDateStr ? popup.formatAgeFromDateStr(popup.installDateStr) : Lang.t("common.unknown"))
    property string distro: "..."
    property string distroVersion: ""
    property string shellName: {
        const sh = Quickshell.env("SHELL") || "sh";
        const parts = sh.split("/");
        return parts[parts.length - 1] || "sh";
    }
    property string terminalRaw: mapTerminalName(Quickshell.env("TERMINAL"))
    property bool terminalLoaded: terminalRaw !== ""
    readonly property string terminalName: !popup.terminalLoaded ? "..." : (popup.terminalRaw || Lang.t("common.unknown"))
    property string wmName: Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("DESKTOP_SESSION") || Quickshell.env("XDG_SESSION_DESKTOP") || "Hyprland"

    readonly property string weatherText: {
        if (ShellState.cachedWeatherStatus === "ok")
            return popup.weatherDesc(ShellState.cachedWeatherCode) + " " + ShellState.cachedWeatherTemp + "°C";
        if (ShellState.cachedWeatherStatus === "offline")
            return Lang.t("profile.weatherOffline");
        if (ShellState.cachedWeatherStatus === "not_found")
            return Lang.t("profile.weatherNotFound");
        return Lang.t("profile.weatherConfigure");
    }
    property string weatherCity: ShellState.cachedWeatherCity
    property int avatarTick: 0

    property int pacmanPkgs: ShellState.cachedPkgs ? ShellState.cachedPkgs.pacman : 0
    property int aurPkgs: ShellState.cachedPkgs ? ShellState.cachedPkgs.aur : 0
    property int flatpakPkgs: ShellState.cachedPkgs ? ShellState.cachedPkgs.flatpak : 0
    property int snapPkgs: ShellState.cachedPkgs ? ShellState.cachedPkgs.snap : 0
    property int brewPkgs: ShellState.cachedPkgs ? ShellState.cachedPkgs.brew : 0
    property int totalPkgs: ShellState.cachedPkgs ? ShellState.cachedPkgs.total : 0

    property real cpuUsagePct: 0
    property real _prevCpuTotal: 0
    property real _prevCpuIdle: 0
    property int cpuTempC: 0
    property bool gpuAvailable: false
    property string gpuUsageLabel: "0"
    property int gpuTempC: 0
    property real ramUsedGb: 0
    property real ramUsagePct: 0

    property var diskList: []

    readonly property int shadowMargin: 14

    implicitWidth: 700 + shadowMargin * 2
    implicitHeight: bg.height + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running

    function mapTerminalName(t) {
        if (!t)
            return "";
        const base = t.split("/").pop().toLowerCase();
        const map = {
            kitty: "Kitty",
            alacritty: "Alacritty",
            wezterm: "WezTerm",
            foot: "Foot",
            konsole: "Konsole",
            "gnome-terminal": "GNOME Terminal",
            tilix: "Tilix",
            "xfce4-terminal": "Xfce Terminal",
            terminator: "Terminator",
            lxterminal: "LXTerminal",
            xterm: "xterm"
        };
        return map[base] || t.split("/").pop();
    }

    function formatAgeFromDateStr(dateStr) {
        const parts = dateStr.split("-");
        if (parts.length !== 3)
            return Lang.t("common.unknown");
        const instMs = Date.UTC(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
        if (isNaN(instMs))
            return Lang.t("common.unknown");
        const daysTotal = Math.max(0, Math.floor((Date.now() - instMs) / 86400000));
        const years = Math.floor(daysTotal / 365);
        const rem = daysTotal % 365;
        const months = Math.floor(rem / 30);
        const rem2 = rem % 30;
        const weeks = Math.floor(rem2 / 7);
        const days = rem2 % 7;

        const out = [];
        if (years > 0) {
            out.push(years + Lang.t("unit.y"));
            if (months > 0)
                out.push(months + Lang.t("unit.m"));
            if (weeks > 0)
                out.push(weeks + Lang.t("unit.w"));
        } else if (months > 0) {
            out.push(months + Lang.t("unit.m"));
            if (weeks > 0)
                out.push(weeks + Lang.t("unit.w"));
            if (days > 0)
                out.push(days + Lang.t("unit.d"));
        } else if (weeks > 0) {
            out.push(weeks + Lang.t("unit.w"));
            if (days > 0)
                out.push(days + Lang.t("unit.d"));
        } else {
            out.push(days + Lang.t("unit.d"));
        }
        return out.length > 0 ? out.join(" ") : ("0" + Lang.t("unit.d"));
    }

    function weatherDesc(code) {
        const keyMap = {
            0: "0",
            1: "1",
            2: "2",
            3: "3",
            45: "45",
            48: "45",
            51: "51",
            53: "51",
            55: "51",
            56: "56",
            57: "56",
            61: "61",
            63: "61",
            65: "61",
            66: "66",
            67: "66",
            71: "71",
            73: "71",
            75: "71",
            77: "77",
            80: "80",
            81: "80",
            82: "80",
            85: "85",
            86: "85",
            95: "95",
            96: "96",
            99: "96"
        };
        const key = keyMap[code];
        return key !== undefined ? Lang.t("wx." + key) : Lang.t("common.unknown");
    }

    function fetchWeather(force) {
        const now = Date.now();
        if (!force && ShellState.cachedWeatherTimestamp > 0 && (now - ShellState.cachedWeatherTimestamp) < 15 * 60 * 1000)
            return;
        const raw = (popup.weatherCity || "Moscow").trim();
        const comma = raw.indexOf(",");
        const cityPart = comma !== -1 ? raw.slice(0, comma).trim() : raw;
        const countryPart = comma !== -1 ? raw.slice(comma + 1).trim().toLowerCase() : "";

        const geoUrl = "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(cityPart) + "&count=10&language=" + encodeURIComponent(AppSettings.language) + "&format=json";
        const xhr = new XMLHttpRequest();
        xhr.timeout = 5000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                ShellState.cachedWeatherStatus = "offline";
                return;
            }
            try {
                const data = JSON.parse(xhr.responseText);
                const results = data.results || [];
                if (results.length === 0) {
                    ShellState.cachedWeatherStatus = "not_found";
                    return;
                }
                let pick = null;
                if (countryPart) {
                    for (let i = 0; i < results.length; i++) {
                        const r = results[i];
                        const c = (r.country || "").toLowerCase();
                        const cc = (r.country_code || "").toLowerCase();
                        if (c.indexOf(countryPart) !== -1 || countryPart === cc) {
                            pick = r;
                            break;
                        }
                    }
                }
                if (!pick)
                    pick = results[0];

                const wxUrl = "https://api.open-meteo.com/v1/forecast?latitude=" + encodeURIComponent(pick.latitude) + "&longitude=" + encodeURIComponent(pick.longitude) + "&current_weather=true";
                const wxReq = new XMLHttpRequest();
                wxReq.timeout = 5000;
                wxReq.onreadystatechange = function () {
                    if (wxReq.readyState !== XMLHttpRequest.DONE)
                        return;
                    if (wxReq.status !== 200) {
                        ShellState.cachedWeatherStatus = "offline";
                        return;
                    }
                    try {
                        const w = JSON.parse(wxReq.responseText);
                        const cw = w.current_weather;
                        ShellState.cachedWeatherCode = cw.weathercode;
                        ShellState.cachedWeatherTemp = Math.round(cw.temperature);
                        ShellState.cachedWeatherStatus = "ok";
                        ShellState.cachedWeatherTimestamp = Date.now();
                    } catch (e) {
                        ShellState.cachedWeatherStatus = "offline";
                    }
                };
                wxReq.ontimeout = function () {
                    ShellState.cachedWeatherStatus = "offline";
                };
                wxReq.open("GET", wxUrl);
                wxReq.send();
            } catch (e) {
                ShellState.cachedWeatherStatus = "offline";
            }
        };
        xhr.ontimeout = function () {
            ShellState.cachedWeatherStatus = "offline";
        };
        xhr.open("GET", geoUrl);
        xhr.send();
    }

    function refreshLiveStats() {
        uptimeFile.reload();
        memFile.reload();
        statFile.reload();
        if (!diskGpuTempReader.running)
            diskGpuTempReader.running = true;
    }

    function refreshOnOpen() {
        hostnameFile.reload();
        osreleaseFile.reload();
        osReleaseFile.reload();
        refreshLiveStats();
        if (!ShellState.cachedPkgs && !pkgReader.running)
            pkgReader.running = true;
        if (!popup.terminalLoaded && !termDetectProc.running)
            termDetectProc.running = true;
        if (!popup.installDateLoaded && !installDateProc.running)
            installDateProc.running = true;
        fetchWeather(false);
    }

    Component.onCompleted: {
        Qt.callLater(() => popup._animReady = true);
        if (popup.open)
            refreshOnOpen();
    }

    Timer {
        id: hideTimer
        interval: 150
    }

    onOpenChanged: {
        if (!open) {
            hideTimer.start();
        } else {
            hideTimer.stop();
            refreshOnOpen();
        }
    }

    FileView {
        id: hostnameFile
        path: "/proc/sys/kernel/hostname"
        printErrors: false
        onLoaded: popup.hostname = text().trim() || "unknown-host"
    }

    FileView {
        id: osreleaseFile
        path: "/proc/sys/kernel/osrelease"
        printErrors: false
        onLoaded: {
            popup.kernelRaw = text().trim();
            popup.kernelLoaded = true;
        }
    }

    FileView {
        id: osReleaseFile
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const lines = text().split("\n");
            let d = "Linux";
            let v = "";
            for (let i = 0; i < lines.length; i++) {
                const l = lines[i];
                if (l.startsWith("PRETTY_NAME="))
                    d = l.slice(12).replace(/^"|"$/g, "");
                else if (l.startsWith("VERSION_ID="))
                    v = l.slice(11).replace(/^"|"$/g, "");
            }
            popup.distro = d || "Linux";
            popup.distroVersion = v || "";
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            popup.uptimeSeconds = Math.floor(parseFloat(text().trim().split(/\s+/)[0]) || 0);
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const lines = text().split("\n");
            let totalKb = 0;
            let availKb = 0;
            for (let i = 0; i < lines.length; i++) {
                const l = lines[i];
                if (l.startsWith("MemTotal:"))
                    totalKb = parseInt(l.replace(/\D+/g, ""), 10) || 0;
                else if (l.startsWith("MemAvailable:"))
                    availKb = parseInt(l.replace(/\D+/g, ""), 10) || 0;
            }
            if (totalKb > 0) {
                const usedKb = Math.max(0, totalKb - availKb);
                popup.ramUsedGb = usedKb / (1024 * 1024);
                popup.ramUsagePct = Math.round(usedKb * 100 / totalKb);
            }
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const firstLine = text().split("\n")[0] || "";
            const parts = firstLine.trim().split(/\s+/);
            if (parts[0] !== "cpu" || parts.length < 5)
                return;
            let total = 0;
            for (let i = 1; i < parts.length; i++)
                total += parseInt(parts[i], 10) || 0;
            const idle = (parseInt(parts[4], 10) || 0) + (parseInt(parts[5], 10) || 0);
            if (popup._prevCpuTotal > 0 && total > popup._prevCpuTotal) {
                const dTotal = total - popup._prevCpuTotal;
                const dIdle = idle - popup._prevCpuIdle;
                popup.cpuUsagePct = Math.max(0, Math.min(100, Math.round((1 - dIdle / dTotal) * 100)));
            } else if (popup._prevCpuTotal === 0) {
                popup.cpuUsagePct = total > 0 ? Math.max(0, Math.min(100, Math.round((1 - idle / total) * 100))) : 0;
                cpuQuickSampleTimer.restart();
            }
            popup._prevCpuTotal = total;
            popup._prevCpuIdle = idle;
        }
    }

    Timer {
        id: cpuQuickSampleTimer
        interval: 250
        onTriggered: if (popup.open)
            statFile.reload()
    }

    Process {
        id: installDateProc
        command: ["sh", "-c", "head -n1 /var/log/pacman.log 2>/dev/null | sed -n 's/^\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\).*/\\1/p'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = this.text.trim();
                popup.installDateStr = d;
                popup.installDateLoaded = true;
                ShellState.cachedInstallDate = d;
            }
        }
    }

    Process {
        id: termDetectProc
        command: ["sh", "-c", "for t in kitty alacritty wezterm foot konsole gnome-terminal tilix xfce4-terminal terminator lxterminal xterm; do command -v \"$t\" >/dev/null 2>&1 && { echo \"$t\"; exit 0; }; done; echo \"\""]
        stdout: StdioCollector {
            onStreamFinished: {
                popup.terminalRaw = popup.mapTerminalName(this.text.trim());
                popup.terminalLoaded = true;
            }
        }
    }

    Process {
        id: pkgReader
        command: ["sh", "-c", "p=$(command -v pacman >/dev/null 2>&1 && pacman -Q 2>/dev/null | wc -l || echo 0);" + "a=$(command -v yay >/dev/null 2>&1 && yay -Qm 2>/dev/null | wc -l || { command -v paru >/dev/null 2>&1 && paru -Qm 2>/dev/null | wc -l; } || echo 0);" + "f=$(command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | wc -l || echo 0);" + "s=$(command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | tail -n+2 | wc -l || echo 0);" + "b=$(command -v brew >/dev/null 2>&1 && brew list 2>/dev/null | wc -l || echo 0);" + "echo \"$p|$a|$f|$s|$b\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                if (parts.length >= 5) {
                    const p = parseInt(parts[0], 10) || 0;
                    const a = parseInt(parts[1], 10) || 0;
                    const f = parseInt(parts[2], 10) || 0;
                    const s = parseInt(parts[3], 10) || 0;
                    const b = parseInt(parts[4], 10) || 0;
                    const total = p + a + f + s + b;
                    popup.pacmanPkgs = p;
                    popup.aurPkgs = a;
                    popup.flatpakPkgs = f;
                    popup.snapPkgs = s;
                    popup.brewPkgs = b;
                    popup.totalPkgs = total;
                    ShellState.cachedPkgs = {
                        pacman: p,
                        aur: a,
                        flatpak: f,
                        snap: s,
                        brew: b,
                        total: total
                    };
                }
            }
        }
    }

    Process {
        id: diskGpuTempReader
        command: ["sh", "-c", "ct=''; for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower|acpitz) ct=$(awk '{print int($1/1000); exit}' \"$d\"/temp*_input 2>/dev/null); [ -n \"$ct\" ] && break;; esac; done; [ -z \"$ct\" ] && ct=$(awk '{print int($1/1000); exit}' /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null); echo \"CT:${ct:-0}\";" + "if command -v nvidia-smi >/dev/null 2>&1; then gd=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' '); [ -n \"$gd\" ] && echo \"GPU:$gd\"; fi;" + "df -h --output=target,size,used,pcent 2>/dev/null | tail -n+2 | while read -r m s u p; do case \"$m\" in /) echo \"DISK:Root|$s|$u|$p\";; /media/*|/mnt/*) echo \"DISK:${m##*/}|$s|$u|$p\";; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const disks = [];
                let hasGpu = false;
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (line.startsWith("CT:")) {
                        popup.cpuTempC = parseInt(line.slice(3), 10) || 0;
                    } else if (line.startsWith("GPU:")) {
                        const gp = line.slice(4).split(",");
                        if (gp.length >= 2) {
                            hasGpu = true;
                            popup.gpuUsageLabel = gp[0] || "0";
                            popup.gpuTempC = parseInt(gp[1], 10) || 0;
                        }
                    } else if (line.startsWith("DISK:")) {
                        const dp = line.slice(5).split("|");
                        if (dp.length >= 4) {
                            disks.push({
                                name: dp[0],
                                size: dp[1],
                                used: dp[2],
                                pct: parseInt(dp[3].replace("%", ""), 10) || 0
                            });
                        }
                    }
                }
                popup.gpuAvailable = hasGpu;
                popup.diskList = disks;
            }
        }
    }

    Timer {
        id: statsRefreshTimer
        interval: 3000
        running: popup.open
        repeat: true
        onTriggered: popup.refreshLiveStats()
    }

    readonly property string weatherConfigPath: AppSettings.weatherConfigPath

    FileView {
        id: weatherCityFile
        path: popup.weatherConfigPath
        printErrors: false
        onLoaded: {
            const c = text().trim();
            if (c) {
                if (c !== ShellState.cachedWeatherCity)
                    ShellState.cachedWeatherTimestamp = 0;
                popup.weatherCity = c;
                ShellState.cachedWeatherCity = c;
            }
            popup.fetchWeather(false);
        }
        onLoadFailed: err => {
            popup.fetchWeather(false);
        }
    }

    Loader {
        id: avatarPickerLoader
        active: false
        sourceComponent: FilePicker {
            pickerTitle: Lang.t("profile.avatarTitle")
            initialDir: Quickshell.env("HOME") + "/Pictures"
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
            onAccepted: path => {
                copyAvatarProc.command = ["sh", "-c", "mkdir -p \"$2\" && cp -- \"$1\" \"$2/avatar.png\" && echo ok", "sh", path, AppSettings.configDir];
                copyAvatarProc.running = true;
            }
        }
    }

    Process {
        id: copyAvatarProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "ok")
                    popup.avatarTick++;
            }
        }
    }

    Loader {
        id: weatherInputLoader
        active: false
        sourceComponent: TextInputPopup {
            popupTitle: Lang.t("profile.weatherTitle")
            promptText: Lang.t("profile.weatherPrompt")
            onAccepted: value => {
                popup.weatherCity = value;
                ShellState.cachedWeatherCity = value;
                ShellState.cachedWeatherTimestamp = 0;
                weatherCityFile.setText(value + "\n");
                popup.fetchWeather(true);
            }
        }
    }

    Rectangle {
        anchors.fill: bg
        anchors.margins: -6
        radius: bg.radius + 6
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: bg.opacity * 0.35
        scale: bg.scale
        transformOrigin: bg.transformOrigin
        z: bg.z - 2
    }
    Rectangle {
        anchors.fill: bg
        anchors.margins: -1
        radius: bg.radius + 1
        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 1)
        opacity: bg.opacity * 0.12
        scale: bg.scale
        transformOrigin: bg.transformOrigin
        z: bg.z - 1
    }

    Rectangle {
        id: bg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: popup.shadowMargin
        height: mainColumn.implicitHeight + 52
        radius: 26
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, AppSettings.popupOpacity)
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
        border.width: 1
        clip: true

        transformOrigin: {
            if (AppSettings.barPosition === "bottom")
                return Item.BottomLeft;
            if (AppSettings.barPosition === "right")
                return Item.TopRight;
            return Item.TopLeft;
        }
        scale: popup.visualOpen ? 1.0 : 0.88
        opacity: popup.visualOpen ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        HoverHandler {
            id: hover
        }

        Rectangle {
            id: gearBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 14
            width: 40
            height: 40
            radius: 12
            z: 10
            color: gearHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            HoverHandler {
                id: gearHover
            }

            Text {
                anchors.centerIn: parent
                text: "󰒓"
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, gearHover.hovered ? 1 : 0.7)
                font.pixelSize: 17
            }

            TapHandler {
                onTapped: ShellState.settingsWindowOpen = true
            }
        }

        ColumnLayout {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 26
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Item {
                    Layout.preferredWidth: 115
                    Layout.preferredHeight: 115

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        visible: avatarImage.status === Image.Ready

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: "file://" + AppSettings.avatarPath + (popup.avatarTick > 0 ? "?t=" + popup.avatarTick : "")
                            sourceSize: Qt.size(230, 230)
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Colors.primary
                        opacity: 0.8
                        visible: avatarImage.status !== Image.Ready
                        Text {
                            anchors.centerIn: parent
                            text: popup.username ? popup.username.charAt(0).toUpperCase() : "U"
                            color: Colors.background
                            font.pixelSize: 46
                            font.bold: true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: avatarHover.hovered ? Colors.primary : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 2
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.5)
                        opacity: avatarHover.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "\uf304"
                            color: "#ffffff"
                            font.pixelSize: 26
                        }
                    }

                    HoverHandler {
                        id: avatarHover
                    }
                    TapHandler {
                        onTapped: {
                            avatarPickerLoader.active = true;
                            Qt.callLater(() => {
                                if (avatarPickerLoader.item)
                                    avatarPickerLoader.item.openAt(avatarPickerLoader.item.initialDir);
                            });
                        }
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Text {
                        text: popup.username
                        color: Colors.surfaceText
                        font.pixelSize: 28
                        font.bold: true
                    }
                    Text {
                        text: popup.hostname
                        color: Colors.primary
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: uptimeLabel.implicitWidth + 26
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    radius: 18
                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                    border.width: 1

                    Text {
                        id: uptimeLabel
                        anchors.centerIn: parent
                        text: "󰔟  " + popup.uptime
                        color: Colors.primary
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: 14
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08)
                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        weatherInputLoader.active = true;
                        Qt.callLater(() => {
                            if (weatherInputLoader.item)
                                weatherInputLoader.item.openWith(popup.weatherCity);
                        });
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    Text {
                        text: popup.weatherText
                        color: Colors.surfaceText
                        font.pixelSize: 16
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        text: popup.weatherCity + "  \uf304"
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.6)
                        font.pixelSize: 14
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                MiniStatCard {
                    Layout.fillWidth: true
                    icon: "󰘚"
                    title: Lang.t("profile.cpu")
                    value: popup.cpuUsagePct + "%"
                    subValue: popup.cpuTempC + "°C"
                    progress: popup.cpuUsagePct / 100
                    progressColor: Colors.primary
                }

                MiniStatCard {
                    Layout.fillWidth: true
                    icon: "󰔂"
                    title: Lang.t("profile.gpu")
                    value: popup.gpuUsageLabel + "%"
                    subValue: popup.gpuTempC + "°C"
                    progress: (parseFloat(popup.gpuUsageLabel) || 0) / 100
                    progressColor: (parseFloat(popup.gpuUsageLabel) || 0) > 85 ? Colors.error : Colors.primary
                    visible: popup.gpuAvailable
                }

                MiniStatCard {
                    Layout.fillWidth: true
                    icon: "󰆼"
                    title: Lang.t("profile.ram")
                    value: popup.ramUsagePct + "%"
                    subValue: popup.ramUsedGb.toFixed(1) + " " + Lang.t("profile.gb")
                    progress: popup.ramUsagePct / 100
                    progressColor: popup.ramUsagePct > 85 ? Colors.error : Colors.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Lang.t("profile.sysInfo")
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    font.pixelSize: 13
                    font.bold: true
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰌽"
                        label: Lang.t("profile.osDistro")
                        value: popup.distro + (popup.distroVersion && popup.distroVersion !== "Rolling" ? " " + popup.distroVersion : "")
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰖯"
                        label: Lang.t("profile.wmDesktop")
                        value: popup.wmName
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰒓"
                        label: Lang.t("profile.kernel")
                        value: popup.kernel
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰒼"
                        label: Lang.t("profile.terminal")
                        value: popup.terminalName
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰋚"
                        label: Lang.t("profile.installed")
                        value: popup.installAge
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰆍"
                        label: Lang.t("profile.userShell")
                        value: popup.shellName
                    }

                    SysTile {
                        Layout.fillWidth: true
                        Layout.columnSpan: 2
                        wrap: true
                        icon: "\uf487"
                        label: Lang.t("profile.packages")
                        value: {
                            var parts = [];
                            if (popup.pacmanPkgs > 0)
                                parts.push("pacman: " + popup.pacmanPkgs);
                            if (popup.aurPkgs > 0)
                                parts.push("aur: " + popup.aurPkgs);
                            if (popup.flatpakPkgs > 0)
                                parts.push("flatpak: " + popup.flatpakPkgs);
                            if (popup.snapPkgs > 0)
                                parts.push("snap: " + popup.snapPkgs);
                            if (popup.brewPkgs > 0)
                                parts.push("brew: " + popup.brewPkgs);
                            return parts.length > 0 ? Lang.t("profile.packagesTotal", {
                                total: popup.totalPkgs,
                                details: parts.join(", ")
                            }) : Lang.t("profile.packagesZero");
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Lang.t("profile.storage")
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    font.pixelSize: 13
                    font.bold: true
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(disksColumn.implicitHeight, 280)
                    contentWidth: width
                    contentHeight: disksColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: disksColumn
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: popup.diskList
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 14
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04)
                                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 14

                                    Rectangle {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        radius: 10
                                        color: modelData.pct > 90 ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.18) : modelData.pct > 70 ? Qt.rgba(1, 0.7, 0.4, 0.18) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name === "Root" ? "󰋊" : "󰆓"
                                            font.pixelSize: 18
                                            color: modelData.pct > 90 ? Colors.error : modelData.pct > 70 ? "#f7b267" : Colors.primary
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: modelData.name === "Root" ? Lang.t("profile.systemDrive") : modelData.name
                                                color: Colors.surfaceText
                                                font.pixelSize: 14
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: Lang.t("profile.driveUsedOf", {
                                                    used: modelData.used,
                                                    size: modelData.size,
                                                    pct: modelData.pct
                                                })
                                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7)
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 6
                                            radius: 3
                                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)

                                            Rectangle {
                                                width: parent.width * Math.min(1, modelData.pct / 100)
                                                height: parent.height
                                                radius: 3
                                                color: modelData.pct > 90 ? Colors.error : modelData.pct > 70 ? "#f7b267" : Colors.primary
                                                Behavior on width {
                                                    NumberAnimation {
                                                        duration: 300
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: popup.diskList.length === 0
                            text: Lang.t("profile.noDrives")
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    component SysTile: Rectangle {
        property string icon: ""
        property string label: ""
        property string value: ""
        property bool wrap: false

        Layout.preferredHeight: wrap ? Math.max(52, contentRow.implicitHeight + 24) : 52
        radius: 12
        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04)
        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
        border.width: 1

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: icon
                font.pixelSize: 16
                color: Colors.primary
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: label
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                    font.pixelSize: 11
                    font.bold: true
                }
                Text {
                    text: value
                    color: Colors.surfaceText
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: wrap ? Text.Wrap : Text.NoWrap
                    elide: wrap ? Text.ElideNone : Text.ElideRight
                    maximumLineCount: wrap ? 3 : 1
                }
            }
        }
    }

    component MiniStatCard: Rectangle {
        property string icon: ""
        property string title: ""
        property string value: ""
        property string subValue: ""
        property real progress: 0
        property color progressColor: Colors.primary

        Layout.preferredHeight: 84
        radius: 14
        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04)
        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: icon
                    font.pixelSize: 16
                    color: progressColor
                }
                Text {
                    text: title
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                    font.pixelSize: 12
                    font.bold: true
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: subValue
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.8)
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: value
                    color: Colors.surfaceText
                    font.pixelSize: 22
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 2.5
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)

                Rectangle {
                    width: parent.width * Math.min(1, progress)
                    height: parent.height
                    radius: 2.5
                    color: progressColor
                    Behavior on width {
                        NumberAnimation {
                            duration: 300
                        }
                    }
                }
            }
        }
    }
}
