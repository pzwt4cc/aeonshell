// GpuStat.qml

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

RowLayout {
    id: root
    spacing: 10

    property string gpuText: "GPU: ..."
    property string vramText: "VRAM: ..."
    property bool available: true

    Text {
        text: root.gpuText
        color: "#ffffff"
        font.pixelSize: 13
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
        visible: root.available
    }

    Separator { visible: root.available }

    Text {
        text: root.vramText
        color: "#ffffff"
        font.pixelSize: 13
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
        visible: root.available
    }

    Process {
        id: proc
        command: ["bash", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then " +
            "  nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used --format=csv,noheader,nounits 2>/dev/null | head -n1; " +
            "elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then " +
            "  busy=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null); " +
            "  temp=$(cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1); " +
            "  vram=$(cat /sys/class/drm/card0/device/mem_info_vram_used 2>/dev/null); " +
            "  echo \"${busy:-0},$(( ${temp:-0} / 1000 )),$(( ${vram:-0} / 1024 / 1024 ))\"; " +
            "else " +
            "  echo 'NA'; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                if (!out || out === "NA") {
                    root.available = false;
                    return;
                }
                const parts = out.split(",").map(s => s.trim());
                if (parts.length >= 3) {
                    root.available = true;
                    root.gpuText = "GPU: " + parts[1] + "°C " + parts[0] + "%";
                    root.vramText = "VRAM: " + (parseFloat(parts[2]) / 1024).toFixed(1) + "GB";
                } else {
                    root.available = false;
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}