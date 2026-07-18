// ProfilePopup.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Qt5Compat.GraphicalEffects

PopupWindow {
    id: popup

    property bool open: false
    readonly property bool isHovered: hover.hovered

    property string username: "..."
    property string hostname: "..."
    property string kernel: "..."
    property string uptime: "..."
    property string installAge: "..."
    property string distro: "..."
    property string distroVersion: ""
    property string shellName: "..."
    property string shellVersion: ""
    property string terminalName: "..."
    property string localeStr: "..."
    property string wmName: "..."
    property string weatherText: "Click to configure"
    property string weatherCity: "Moscow"
    property bool weatherFetched: false

    property int pacmanPkgs: 0
    property int aurPkgs: 0
    property int flatpakPkgs: 0
    property int snapPkgs: 0
    property int brewPkgs: 0
    property int totalPkgs: 0

    property real cpuUsagePct: 0
    property int cpuTempC: 0
    property bool gpuAvailable: true
    property string gpuUsageLabel: "0"
    property int gpuTempC: 0
    property real gpuVramTotalGb: 0
    property real gpuVramUsedGb: 0
    property real ramTotalGb: 0
    property real ramUsedGb: 0
    property real ramUsagePct: 0

    property var diskList: []

    readonly property int shadowMargin: 14

    implicitWidth: 700 + shadowMargin * 2
    implicitHeight: 980 + shadowMargin * 2
    color: "transparent"
    visible: popup.open || hideTimer.running


    Timer { 
        id: hideTimer
        interval: 150 
    }

    onOpenChanged: {
        if (!open) {
            hideTimer.start()
        } else {
            hideTimer.stop()
            sysInfoReader.running = true
            pkgReader.running = true
            shellTermReader.running = true
            installAgeReader.running = true
            if (!weatherFetched) weatherReader.running = true
            statsReader.running = true
        }
    }

    Process {
        id: sysInfoReader
        command: ["bash", "-c", `
u=$(whoami 2>/dev/null); echo "\${u:-User}"
h=$(cat /proc/sys/kernel/hostname 2>/dev/null || hostnamectl --static 2>/dev/null || hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || uname -n 2>/dev/null); echo "\${h:-unknown-host}"
k=$(uname -r 2>/dev/null); echo "\${k:-Unknown}"
up=$(awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); printf "%s%s%dm", (d>0?d"d ":""), (h>0?h"h ":""), m}' /proc/uptime 2>/dev/null); echo "\${up:-Unknown}"
d=$(grep -m1 '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"'); echo "\${d:-Linux}"
v=$(grep -m1 '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"'); echo "\${v:-}"
w=$(echo "\${XDG_CURRENT_DESKTOP:-\${DESKTOP_SESSION:-\${XDG_SESSION_DESKTOP}}}"); echo "\${w:-Unknown}"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                popup.username = lines[0] || "User"
                popup.hostname = lines[1] || "unknown-host"
                popup.kernel = lines[2] || "Unknown"
                popup.uptime = lines[3] || "Unknown"
                popup.distro = lines[4] || "Linux"
                popup.distroVersion = lines[5] || ""
                popup.wmName = lines[6] || "Unknown"
            }
        }
    }

    Process {
        id: installAgeReader
        command: ["bash", "-c", `
log=/var/log/pacman.log
if [ -f "$log" ]; then
    first=$(head -n1 "$log" | grep -oP '^\\[\\K[0-9-]+')
    if [ -n "$first" ]; then
        inst=$(date -d "$first" +%s 2>/dev/null)
        now=$(date +%s)
        if [ -n "$inst" ]; then
            total_days=$(( (now - inst) / 86400 ))
            python3 -c "
days_total = $total_days
years = days_total // 365
rem = days_total % 365
months = rem // 30
rem2 = rem % 30
weeks = rem2 // 7
days = rem2 % 7

parts = []
if years > 0:
    parts.append(f'{years}y')
    if months > 0: parts.append(f'{months}m')
    if weeks > 0: parts.append(f'{weeks}w')
elif months > 0:
    parts.append(f'{months}m')
    if weeks > 0: parts.append(f'{weeks}w')
    if days > 0: parts.append(f'{days}d')
elif weeks > 0:
    parts.append(f'{weeks}w')
    if days > 0: parts.append(f'{days}d')
else:
    parts.append(f'{days}d')

print(' '.join(parts) if parts else '0d')
"
        else
            echo "Unknown"
        fi
    else
        echo "Unknown"
    fi
else
    echo "Unknown"
fi
`]
        stdout: StdioCollector {
            onStreamFinished: {
                popup.installAge = this.text.trim() || "Unknown"
            }
        }
    }

    Process {
        id: pkgReader
        command: ["bash", "-c", `
p=$(command -v pacman >/dev/null 2>&1 && pacman -Q 2>/dev/null | wc -l || echo 0)
a=$(command -v yay >/dev/null 2>&1 && yay -Qm 2>/dev/null | wc -l || { command -v paru >/dev/null 2>&1 && paru -Qm 2>/dev/null | wc -l; } || echo 0)
f=$(command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | wc -l || echo 0)
s=$(command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | tail -n+2 | wc -l || echo 0)
b=$(command -v brew >/dev/null 2>&1 && brew list 2>/dev/null | wc -l || echo 0)
echo "$p|$a|$f|$s|$b"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|")
                if (parts.length >= 5) {
                    popup.pacmanPkgs = parseInt(parts[0]) || 0
                    popup.aurPkgs = parseInt(parts[1]) || 0
                    popup.flatpakPkgs = parseInt(parts[2]) || 0
                    popup.snapPkgs = parseInt(parts[3]) || 0
                    popup.brewPkgs = parseInt(parts[4]) || 0
                    popup.totalPkgs = popup.pacmanPkgs + popup.aurPkgs + popup.flatpakPkgs + popup.snapPkgs + popup.brewPkgs
                }
            }
        }
    }

    Process {
        id: shellTermReader
        command: ["bash", "-c", `
sh=$(basename "$SHELL" 2>/dev/null); echo "\${sh:-sh}"

term=""
if [ -n "$TERMINAL" ]; then
    term="$TERMINAL"
else
    for t in kitty alacritty wezterm foot konsole gnome-terminal tilix xfce4-terminal terminator lxterminal xterm; do
        if command -v "$t" >/dev/null 2>&1; then term="$t"; break; fi
    done
fi

case "$term" in
    kitty) term="Kitty" ;;
    alacritty) term="Alacritty" ;;
    wezterm) term="WezTerm" ;;
    foot) term="Foot" ;;
    konsole) term="Konsole" ;;
    gnome-terminal) term="GNOME Terminal" ;;
    tilix) term="Tilix" ;;
    xfce4-terminal) term="Xfce Terminal" ;;
    terminator) term="Terminator" ;;
    lxterminal) term="LXTerminal" ;;
    xterm) term="xterm" ;;
    "") term="Unknown" ;;
esac

echo "$term"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                popup.shellName = lines[0] || "sh"
                popup.terminalName = lines[1] || "Unknown"
            }
        }
    }

    Process {
        id: statsReader
        command: [
            "bash", "-c",
            "cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print int($2+$4+$6)}');" +
            "cpu_temp=$(cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null | head -n1 | awk '{print int($1/1000)}');" +
            "[ -z \"$cpu_temp\" ] && cpu_temp=0;" +
            "gpu_avail=false; gpu_usage=0; gpu_temp=0; gpu_vram_total=0; gpu_vram_used=0;" +
            "if command -v nvidia-smi >/dev/null 2>&1; then" +
            "  gpu_data=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.total,memory.used --format=csv,noheader,nounits 2>/dev/null | head -n1);" +
            "  if echo \"$gpu_data\" | grep -qE '^[0-9]+, *[0-9]+, *[0-9]+, *[0-9]+$'; then" +
            "    gpu_avail=true;" +
            "    gpu_usage=$(echo $gpu_data | cut -d',' -f1 | xargs);" +
            "    gpu_temp=$(echo $gpu_data | cut -d',' -f2 | xargs);" +
            "    gpu_vram_total=$(echo $gpu_data | cut -d',' -f3 | xargs);" +
            "    gpu_vram_used=$(echo $gpu_data | cut -d',' -f4 | xargs);" +
            "  fi;" +
            "fi;" +
            "read total used _ <<< $(free -b | awk 'NR==2{print $2,$3}');" +
            "ram_total=$((total/1024/1024)); ram_used=$((used/1024/1024)); ram_usage=$((ram_used*100/ram_total));" +
            "echo \"DISKS_START\";" +
            "df -h --output=target,size,used,pcent 2>/dev/null | tail -n+2 | while read -r mount size used pct; do" +
            "  [ \"$mount\" = \"/\" ] && echo \"Root|$size|$used|$pct\" && continue;" +
            "  [[ \"$mount\" == /media/* ]] && echo \"$(basename $mount)|$size|$used|$pct\" && continue;" +
            "  [[ \"$mount\" == /mnt/* ]] && echo \"$(basename $mount)|$size|$used|$pct\" && continue;" +
            "done;" +
            "echo \"DISKS_END\";" +
            "echo \"STATS:$cpu_usage|$cpu_temp|$gpu_avail|$gpu_usage|$gpu_temp|$gpu_vram_total|$gpu_vram_used|$ram_total|$ram_used|$ram_usage\""
        ]
        stdout: StdioCollector {
            property var diskData: []
            property bool readingDisks: false

            onStreamFinished: {
                const lines = this.text.trim().split('\n')
                let statsLine = ""
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (line === "DISKS_START") { readingDisks = true; diskData = []; continue }
                    if (line === "DISKS_END") { readingDisks = false; continue }
                    if (readingDisks) {
                        const parts = line.split('|')
                        if (parts.length >= 4) {
                            diskData.push({
                                name: parts[0],
                                size: parts[1],
                                used: parts[2],
                                pct: parseInt(parts[3].replace('%','')) || 0
                            })
                        }
                    }
                    if (line.startsWith("STATS:")) statsLine = line.substring(6)
                }
                popup.diskList = diskData
                if (statsLine) {
                    const s = statsLine.split("|")
                    if (s.length >= 10) {
                        popup.cpuUsagePct = parseInt(s[0]) || 0
                        popup.cpuTempC = parseInt(s[1]) || 0
                        popup.gpuAvailable = s[2] === "true"
                        popup.gpuUsageLabel = s[3] || "0"
                        popup.gpuTempC = parseInt(s[4]) || 0
                        popup.gpuVramTotalGb = (parseFloat(s[5]) || 0) / 1024
                        popup.gpuVramUsedGb = (parseFloat(s[6]) || 0) / 1024
                        popup.ramTotalGb = (parseFloat(s[7]) || 0) / 1024
                        popup.ramUsedGb = (parseFloat(s[8]) || 0) / 1024
                        popup.ramUsagePct = parseInt(s[9]) || 0
                    }
                }
            }
        }
    }

    Timer {
        id: statsRefreshTimer
        interval: 3000
        running: popup.open
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (!statsReader.running) statsReader.running = true
        }
    }

    property string weatherConfigPath: Quickshell.env("HOME") + "/.config/quickshell/weather_city.conf"

    Component.onCompleted: { weatherCityReader.running = true }

    Process {
        id: weatherCityReader
        command: ["bash", "-c", 'cat "$1" 2>/dev/null || echo Moscow', "bash", popup.weatherConfigPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = this.text.trim()
                if (c) {
                    popup.weatherCity = c
                    popup.weatherFetched = false
                    weatherReader.running = true
                }
            }
        }
    }

    Process {
        id: weatherReader
        command: ["bash", "-c", `
raw="$1"
if echo "$raw" | grep -q ','; then
  cityPart=$(echo "$raw" | cut -d',' -f1 | sed 's/^[ \\t]*//;s/[ \\t]*$//')
  countryPart=$(echo "$raw" | cut -d',' -f2- | sed 's/^[ \\t]*//;s/[ \\t]*$//')
else
  cityPart="$raw"
  countryPart=""
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "No connection"
  exit 0
fi

geo=$(curl -s --max-time 5 -G \\
  --data-urlencode "name=$cityPart" \\
  --data-urlencode "count=10" \\
  --data-urlencode "language=en" \\
  --data-urlencode "format=json" \\
  "https://geocoding-api.open-meteo.com/v1/search" 2>/dev/null)

export WEATHER_COUNTRY="$countryPart"
coords=$(echo "$geo" | python3 -c '
import json, os, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
results = data.get("results") or []
if not results:
    sys.exit(1)
country = os.environ.get("WEATHER_COUNTRY", "").strip().lower()
pick = None
if country:
    for r in results:
        c = (r.get("country") or "").lower()
        cc = (r.get("country_code") or "").lower()
        if country in c or country == cc:
            pick = r
            break
if pick is None:
    pick = results[0]
print(pick["latitude"])
print(pick["longitude"])
' 2>/dev/null)

if [ -z "$coords" ]; then echo "No connection"; exit 0; fi
lat=$(echo "$coords" | sed -n '1p')
lon=$(echo "$coords" | sed -n '2p')

wx=$(curl -s --max-time 5 "https://api.open-meteo.com/v1/forecast?latitude=\${lat}&longitude=\${lon}&current_weather=true" 2>/dev/null)
out=$(echo "$wx" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    cw = d["current_weather"]
    temp = cw["temperature"]
    code = cw["weathercode"]
except Exception:
    sys.exit(1)
desc_map = {
    0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Fog",
    51: "Drizzle", 53: "Drizzle", 55: "Drizzle",
    56: "Freezing drizzle", 57: "Freezing drizzle",
    61: "Rain", 63: "Rain", 65: "Rain",
    66: "Freezing rain", 67: "Freezing rain",
    71: "Snow", 73: "Snow", 75: "Snow",
    77: "Snow grains",
    80: "Rain showers", 81: "Rain showers", 82: "Rain showers",
    85: "Snow showers", 86: "Snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with hail", 99: "Thunderstorm with hail",
}
desc = desc_map.get(code, "Unknown")
print("%s %.0f\u00b0C" % (desc, round(temp)))
' 2>/dev/null)

if [ -z "$out" ]; then echo "No connection"; else echo "$out"; fi
`, "bash", popup.weatherCity]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                const looksValid = t.length > 0 && (t.includes("°") || /\d/.test(t))
                popup.weatherText = looksValid ? t : "No connection"
                popup.weatherFetched = true
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            popup.weatherFetched = false
            weatherReader.running = true
        }
    }

    FilePicker {
        id: avatarPicker
        pickerTitle: "Choose Avatar"
        initialDir: Quickshell.env("HOME") + "/Pictures"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        onAccepted: (path) => {
            copyAvatarProc.command = [
                "bash", "-c",
                'mkdir -p ~/.config/quickshell && cp "$1" ~/.config/quickshell/avatar.png && echo ok',
                "bash", path
            ]
            copyAvatarProc.running = true
        }
    }

    Process {
        id: copyAvatarProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "ok") {
                    avatarImage.source = "file://" + Quickshell.env("HOME") + "/.config/quickshell/avatar.png?t=" + Date.now()
                }
            }
        }
    }

    TextInputPopup {
        id: weatherCityInput
        popupTitle: "Weather Location"
        promptText: "Enter City, Country (e.g. London,UK):"
        onAccepted: (value) => {
            saveWeatherCityProc.command = [
                "bash", "-c",
                'mkdir -p ~/.config/quickshell && printf "%s\\n" "$1" > "$2"',
                "bash", value, popup.weatherConfigPath
            ]
            popup.weatherCity = value
            popup.weatherFetched = false
            saveWeatherCityProc.running = true
            weatherReader.running = true
        }
    }

    Process { id: saveWeatherCityProc }

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
        anchors.fill: parent
        anchors.margins: popup.shadowMargin
        radius: 26
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.96)
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)
        border.width: 1
        clip: true

        transformOrigin: {
            if (AppSettings.barPosition === "bottom") return Item.BottomLeft
            if (AppSettings.barPosition === "right") return Item.TopRight
            return Item.TopLeft
        }
        scale: popup.open ? 1.0 : 0.88
        opacity: popup.open ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        HoverHandler { id: hover }

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
            Behavior on color { ColorAnimation { duration: 150 } }

            HoverHandler { id: gearHover }

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
            anchors.fill: parent
            anchors.margins: 26
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Item {
                    Layout.preferredWidth: 115
                    Layout.preferredHeight: 115

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/avatar.png"
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        visible: status === Image.Ready
                        layer.enabled: visible
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarImage.width
                                height: avatarImage.height
                                radius: width / 2
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Colors.primary
                        opacity: 0.8
                        visible: !avatarImage.visible
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
                        border.color: avatarHover.hovered ? Colors.primary : Qt.rgba(1,1,1,0.12)
                        border.width: 2
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0,0,0,0.5)
                        opacity: avatarHover.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\uf304"
                            color: "#ffffff"
                            font.pixelSize: 26
                        }
                    }

                    HoverHandler { id: avatarHover }
                    TapHandler { onTapped: avatarPicker.openAt(avatarPicker.initialDir) }
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

                Item { Layout.fillWidth: true }

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
                    onClicked: weatherCityInput.openWith(popup.weatherCity)
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
                    title: "CPU usage"
                    value: popup.cpuUsagePct + "%"
                    subValue: popup.cpuTempC + "°C"
                    progress: popup.cpuUsagePct / 100
                    progressColor: Colors.primary
                }

                MiniStatCard {
                    Layout.fillWidth: true
                    icon: "󰔂"
                    title: "GPU usage"
                    value: popup.gpuUsageLabel + "%"
                    subValue: popup.gpuTempC + "°C"
                    progress: (parseFloat(popup.gpuUsageLabel) || 0) / 100
                    progressColor: (parseFloat(popup.gpuUsageLabel) || 0) > 85 ? Colors.error : Colors.primary
                    visible: popup.gpuAvailable
                }

                MiniStatCard {
                    Layout.fillWidth: true
                    icon: "󰆼"
                    title: "RAM memory"
                    value: popup.ramUsagePct + "%"
                    subValue: popup.ramUsedGb.toFixed(1) + " GB"
                    progress: popup.ramUsagePct / 100
                    progressColor: popup.ramUsagePct > 85 ? Colors.error : Colors.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "System Information"
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
                        label: "OS Distro"
                        value: popup.distro + (popup.distroVersion && popup.distroVersion !== "Rolling" ? " " + popup.distroVersion : "")
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰖯"
                        label: "WM / Desktop"
                        value: popup.wmName
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰒓"
                        label: "Kernel Version"
                        value: popup.kernel
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰒼"
                        label: "Terminal"
                        value: popup.terminalName
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰋚"
                        label: "Installed"
                        value: popup.installAge
                    }
                    SysTile {
                        Layout.fillWidth: true
                        icon: "󰆍"
                        label: "User Shell"
                        value: popup.shellName + (popup.shellVersion ? " " + popup.shellVersion : "")
                    }

                    SysTile {
                        Layout.fillWidth: true
                        Layout.columnSpan: 2
                        wrap: true
                        icon: "\uf487"
                        label: "Packages"
                        value: {
                            var parts = []
                            if (popup.pacmanPkgs > 0) parts.push("pacman: " + popup.pacmanPkgs)
                            if (popup.aurPkgs > 0) parts.push("aur: " + popup.aurPkgs)
                            if (popup.flatpakPkgs > 0) parts.push("flatpak: " + popup.flatpakPkgs)
                            if (popup.snapPkgs > 0) parts.push("snap: " + popup.snapPkgs)
                            if (popup.brewPkgs > 0) parts.push("brew: " + popup.brewPkgs)
                            return parts.length > 0 ? popup.totalPkgs + " total (" + parts.join(", ") + ")" : "0 total"
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Storage & Drives"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    font.pixelSize: 13
                    font.bold: true
                }

                Repeater {
                    model: popup.diskList
                    delegate: Rectangle {
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
                                color: modelData.pct > 90 ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.18) :
                                       modelData.pct > 70 ? Qt.rgba(1, 0.7, 0.4, 0.18) :
                                       Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name === "Root" ? "󰋊" : "󰆓"
                                    font.pixelSize: 18
                                    color: modelData.pct > 90 ? Colors.error :
                                           modelData.pct > 70 ? "#f7b267" : Colors.primary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.name === "Root" ? "System Drive (Root)" : modelData.name
                                        color: Colors.surfaceText
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.used + " of " + modelData.size + " (" + modelData.pct + "%)"
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
                                        color: modelData.pct > 90 ? Colors.error :
                                               modelData.pct > 70 ? "#f7b267" : Colors.primary
                                        Behavior on width { NumberAnimation { duration: 300 } }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: popup.diskList.length === 0
                    text: "No mounted storage drives detected"
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                    font.pixelSize: 13
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
                Item { Layout.fillWidth: true }
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
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
        }
    }
}