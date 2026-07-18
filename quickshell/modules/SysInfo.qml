// SysInfo.qml

import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 16

    MetricPill {
        command: "temp=$(cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null | head -n1 | awk '{print int($1/1000)}'); usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print int($2+$4)}'); echo \"CPU: ${temp}°C ${usage}%\""
        intervalMs: 2000
    }

    Separator {}

    GpuStat {}

    Separator {}

    MetricPill {
        command: "free -g | awk '/Mem:/ {printf \"RAM: %s/%sG\", $3, $2}'"
        intervalMs: 2000
    }
}