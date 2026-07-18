// SettingsWindow.qml

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

FloatingWindow {
    id: settingsWin

    title: "Quickshell Settings"

    readonly property var activeScreen: {
        const mon = Hyprland.focusedMonitor;
        if (mon) {
            for (const s of Quickshell.screens) {
                if (s.name === mon.name) return s;
            }
        }
        return Quickshell.screens[0];
    }
    screen: activeScreen

    onClosed: {
        ShellState.settingsWindowOpen = false;
        settingsWin.visible = Qt.binding(function() { return ShellState.settingsWindowOpen; });
    }

    visible: ShellState.settingsWindowOpen
    color: "transparent"

    implicitWidth: 760
    implicitHeight: 560

    property string currentSection: "bar"

    Connections {
        target: ShellState
        function onSettingsWindowOpenChanged() {
            if (ShellState.settingsWindowOpen) {
                settingsWin.currentSection = ShellState.settingsSection;
            }
        }
    }

    RectangularShadow {
        anchors.fill: winBg
        anchors.margins: -10
        radius: winBg.radius
        color: Qt.rgba(0, 0, 0, 0.35)
        blur: 24
        spread: 0
        offset: Qt.point(0, 6)
    }

    QtObject {
        id: hyprlockState
        property int blur_passes: 2
        property real contrast: 0.8916
        property real brightness: 0.8172
        property real vibrancy: 0.1696
        property real vibrancy_darkness: 0.0

        function updateConf(key, val) {
            hlWriteProc.command = ["bash", "-c", `sed -i -E "s/^[[:space:]]*${key}[[:space:]]*=.*/    ${key} = ${val}/" ~/.config/hypr/hyprlock.conf`];
            hlWriteProc.running = true;
        }
    }

    Process { id: hlWriteProc }

    FileView {
        id: hlConfReader
        path: Quickshell.env("HOME") + "/.config/hypr/hyprlock.conf"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const t = hlConfReader.text();
            let m;
            m = t.match(/^\s*blur_passes\s*=\s*([0-9.]+)/m); if (m) hyprlockState.blur_passes = parseInt(m[1]);
            m = t.match(/^\s*contrast\s*=\s*([0-9.]+)/m); if (m) hyprlockState.contrast = parseFloat(m[1]);
            m = t.match(/^\s*brightness\s*=\s*([0-9.]+)/m); if (m) hyprlockState.brightness = parseFloat(m[1]);
            m = t.match(/^\s*vibrancy\s*=\s*([0-9.]+)/m); if (m) hyprlockState.vibrancy = parseFloat(m[1]);
            m = t.match(/^\s*vibrancy_darkness\s*=\s*([0-9.]+)/m); if (m) hyprlockState.vibrancy_darkness = parseFloat(m[1]);
        }
        onFileChanged: reload()
    }

    Rectangle {
        id: winBg
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.98)
        border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    anchors.rightMargin: 34
                    cursorShape: Qt.SizeAllCursor
                    onPressed: mouse => settingsWin.startSystemMove()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Settings"
                    color: Colors.surfaceText
                    font.pixelSize: 18
                    font.bold: true
                }

                Rectangle {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 8
                    color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    HoverHandler { id: closeHover }
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: Colors.surfaceText
                        font.pixelSize: 12
                    }
                    TapHandler {
                        onTapped: ShellState.settingsWindowOpen = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                ColumnLayout {
                    Layout.preferredWidth: 150
                    Layout.minimumWidth: 150
                    Layout.maximumWidth: 150
                    Layout.fillHeight: true
                    spacing: 4

                    NavItem {
                        label: "Bar"
                        icon: "󰍜"
                        selected: settingsWin.currentSection === "bar"
                        onClicked: settingsWin.currentSection = "bar"
                    }
                    NavItem {
                        label: "Keybinds"
                        icon: "󰌌"
                        selected: settingsWin.currentSection === "keybinds"
                        onClicked: settingsWin.currentSection = "keybinds"
                    }
                    NavItem {
                        label: "Hyprlock"
                        icon: "󰌾"
                        selected: settingsWin.currentSection === "hyprlock"
                        onClicked: settingsWin.currentSection = "hyprlock"
                    }
                    NavItem {
                        label: "About"
                        icon: "󰋼"
                        selected: settingsWin.currentSection === "about"
                        onClicked: settingsWin.currentSection = "about"
                    }

                    Item { Layout.fillHeight: true }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    ColumnLayout {
                        visible: settingsWin.currentSection === "bar"
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "PANEL POSITION"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 12
                            rowSpacing: 12

                            PositionOption {
                                label: "Top"
                                pos: "top"
                                selected: AppSettings.barPosition === "top"
                                onClicked: AppSettings.barPosition = "top"
                            }
                            PositionOption {
                                label: "Bottom"
                                pos: "bottom"
                                selected: AppSettings.barPosition === "bottom"
                                onClicked: AppSettings.barPosition = "bottom"
                            }
                            PositionOption {
                                label: "Left"
                                pos: "left"
                                selected: AppSettings.barPosition === "left"
                                onClicked: AppSettings.barPosition = "left"
                            }
                            PositionOption {
                                label: "Right"
                                pos: "right"
                                selected: AppSettings.barPosition === "right"
                                onClicked: AppSettings.barPosition = "right"
                            }
                        }

                        Text {
                            text: "MODULES"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1
                            Layout.topMargin: 8
                        }

                        SettingRow {
                            label: "Media player"
                            checked: AppSettings.barShowPlayer
                            onToggled: AppSettings.barShowPlayer = !AppSettings.barShowPlayer
                        }
                        SettingRow {
                            label: "Tray icons"
                            checked: AppSettings.barShowTray
                            onToggled: AppSettings.barShowTray = !AppSettings.barShowTray
                        }

                        Text {
                            text: "LAYOUT"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1
                            Layout.topMargin: 8
                        }

                        SettingRow {
                            label: "Edge-to-edge"
                            checked: AppSettings.edgeToEdge
                            onToggled: AppSettings.edgeToEdge = !AppSettings.edgeToEdge
                        }
                    }

                    ColumnLayout {
                        visible: settingsWin.currentSection === "keybinds"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        Text {
                            text: "KEYBINDS (read-only, edit bind.conf to change)"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        FileView {
                            id: bindFile
                            path: Quickshell.env("HOME") + "/.config/hypr/conf/bind.conf"
                            watchChanges: true
                            printErrors: false
                            onLoaded: keybindsModel.parse(bindFile.text())
                            onFileChanged: reload()
                        }

                        QtObject {
                            id: keybindsModel
                            property var rows: []

                            function dirName(d) {
                                const m = { l: "left", r: "right", u: "up", d: "down",
                                            left: "left", right: "right", up: "up", down: "down" };
                                return m[d.toLowerCase()] || d;
                            }

                            function keyLabel(key) {
                                if (key === "mouse:272") return "Mouse Left";
                                if (key === "mouse:273") return "Mouse Right";
                                if (key === "grave") return "` (grave)";
                                return key;
                            }

                            function describe(dispatcher, argsStr) {
                                const d = dispatcher.toLowerCase();
                                if (d === "exec") {
                                    if (/set-volume.*5%\+/.test(argsStr)) return "Volume up (+5%)";
                                    if (/set-volume.*5%-/.test(argsStr)) return "Volume down (−5%)";
                                    if (/set-mute/.test(argsStr)) return "Mute / unmute volume";
                                    if (/screenshot full/.test(argsStr)) return "Screenshot — full screen";
                                    if (/screenshot region/.test(argsStr)) return "Screenshot — select region";
                                    if (/clipboard toggle/.test(argsStr)) return "Toggle clipboard history";
                                    if (/launcher toggle/.test(argsStr)) return "Toggle app launcher";
                                    if (/toggle_special_focus/.test(argsStr)) return "Toggle special workspace focus";
                                    return "Launch " + argsStr;
                                }
                                if (d === "killactive") return "Close active window";
                                if (d === "togglefloating") return "Toggle floating";
                                if (d === "fullscreen") return "Toggle fullscreen";
                                if (d === "workspace") return "Switch to workspace " + argsStr;
                                if (d === "movetoworkspace") return argsStr === "special"
                                    ? "Move window to special workspace" : "Move window to workspace " + argsStr;
                                if (d === "movefocus") return "Focus " + keybindsModel.dirName(argsStr) + " window";
                                if (d === "movewindow") return argsStr ? "Move window " + keybindsModel.dirName(argsStr) : "Move window (drag)";
                                if (d === "resizewindow") return "Resize window (drag)";
                                return dispatcher + (argsStr ? " " + argsStr : "");
                            }

                            function parse(text) {
                                const vars = {};
                                const lines = text.split("\n");
                                for (const raw of lines) {
                                    const vm = raw.match(/^\s*\$(\w+)\s*=\s*(.+?)\s*$/);
                                    if (vm && !/^bind/i.test(raw.trim())) vars[vm[1]] = vm[2];
                                }
                                function sub(s) {
                                    return s.replace(/\$(\w+)/g, (m, name) => vars[name] !== undefined ? vars[name] : m);
                                }
                                const out = [];
                                for (const raw of lines) {
                                    const bm = raw.match(/^\s*(bind[a-z]*)\s*=\s*(.+?)\s*$/i);
                                    if (!bm) continue;
                                    const parts = bm[2].split(",").map(p => sub(p.trim()));
                                    const mod = parts[0] || "";
                                    const key = keybindsModel.keyLabel(parts[1] || "");
                                    const rawAction = parts.slice(2).join(", ");
                                    const dispatcher = (parts[2] || "").trim();
                                    const argsStr = parts.slice(3).join(", ");
                                    out.push({
                                        combo: (mod ? mod + " + " : "") + key,
                                        action: keybindsModel.describe(dispatcher, argsStr) || rawAction
                                    });
                                }
                                keybindsModel.rows = out;
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: keybindsCol.height
                            ScrollBar.vertical: ScrollBar {}

                            ColumnLayout {
                                id: keybindsCol
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: keybindsModel.rows
                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 210
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: Qt.rgba(1, 1, 1, 0.07)
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.combo
                                                color: Colors.primary
                                                font.pixelSize: 14
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.action
                                            color: Colors.surfaceText
                                            font.pixelSize: 14
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: settingsWin.currentSection === "hyprlock"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 14

                        Text {
                            text: "LOCK SCREEN (HYPRLOCK)"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 200
                            Layout.preferredHeight: 320
                            radius: 16
                            clip: true
                            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                            border.width: 1

                            Image {
                                id: hlBg
                                anchors.fill: parent
                                source: "file://" + Quickshell.env("HOME") + "/.config/hypr/assets/background.jpg?t=" + hyprlockAssetsState.bgTick
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: false 
                            }

                            MultiEffect {
                                anchors.fill: hlBg
                                source: hlBg
                                blurEnabled: hyprlockState.blur_passes > 0
                                blur: Math.min(1.0, hyprlockState.blur_passes * 0.25)
                                blurMax: 64
                                contrast: hyprlockState.contrast - 1.0
                                brightness: hyprlockState.brightness - 1.0
                            }
                            
                            Rectangle {
                                anchors.fill: parent
                                color: "black"
                                opacity: hyprlockState.vibrancy_darkness * 0.5
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 18

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: -4
                                    Text {
                                        text: Qt.formatTime(new Date(), "hh:mm")
                                        font.pixelSize: 42
                                        font.bold: true
                                        color: Qt.rgba(1, 1, 1, 0.8)
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: Qt.formatDate(new Date(), "dddd, dd MMMM")
                                        font.pixelSize: 12
                                        color: Qt.rgba(1, 1, 1, 0.8)
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 64
                                    Layout.preferredHeight: 64

                                    Image {
                                        id: hlAvatar
                                        anchors.fill: parent
                                        source: "file://" + Quickshell.env("HOME") + "/.config/hypr/assets/user.jpg?t=" + hyprlockAssetsState.avatarTick
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: status === Image.Ready
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle { width: 64; height: 64; radius: 32 }
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 32
                                            border.color: Qt.rgba(1,1,1,0.7)
                                            border.width: 1.5
                                            color: "transparent"
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 180
                                    height: 36
                                    radius: 18
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    border.color: Qt.rgba(1, 1, 1, 0.5)
                                    border.width: 1.5
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "<i>Password...</i>"
                                        color: Qt.rgba(1, 1, 1, 0.6)
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 32
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.2)
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "Change Background"; color: "white"; font.pixelSize: 11; font.bold: true }
                                HoverHandler { id: bgHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: hyprlockBackgroundPicker.openAt(hyprlockBackgroundPicker.initialDir) }
                                opacity: bgHover.hovered ? 1.0 : 0.8
                            }

                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 32
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.2)
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "Change Avatar"; color: "white"; font.pixelSize: 11; font.bold: true }
                                HoverHandler { id: avaHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: hyprlockAvatarPicker.openAt(hyprlockAvatarPicker.initialDir) }
                                opacity: avaHover.hovered ? 1.0 : 0.8
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 200
                            clip: true
                            contentHeight: hlSettingsCol.height
                            ScrollBar.vertical: ScrollBar {}

                            ColumnLayout {
                                id: hlSettingsCol
                                width: parent.width - 14
                                spacing: 12

                                SettingsSlider {
                                    label: "Blur Passes"
                                    value: hyprlockState.blur_passes
                                    from: 0; to: 5; decimals: 0
                                    onReleased: val => hyprlockState.updateConf("blur_passes", Math.round(val))
                                    onMoved: val => hyprlockState.blur_passes = Math.round(val)
                                }
                                SettingsSlider {
                                    label: "Contrast"
                                    value: hyprlockState.contrast
                                    from: 0.0; to: 2.0; decimals: 4
                                    onReleased: val => hyprlockState.updateConf("contrast", val.toFixed(4))
                                    onMoved: val => hyprlockState.contrast = val
                                }
                                SettingsSlider {
                                    label: "Brightness"
                                    value: hyprlockState.brightness
                                    from: 0.0; to: 2.0; decimals: 4
                                    onReleased: val => hyprlockState.updateConf("brightness", val.toFixed(4))
                                    onMoved: val => hyprlockState.brightness = val
                                }
                                SettingsSlider {
                                    label: "Vibrancy"
                                    value: hyprlockState.vibrancy
                                    from: 0.0; to: 1.0; decimals: 4
                                    onReleased: val => hyprlockState.updateConf("vibrancy", val.toFixed(4))
                                    onMoved: val => hyprlockState.vibrancy = val
                                }
                                SettingsSlider {
                                    label: "Vibrancy Darkness"
                                    value: hyprlockState.vibrancy_darkness
                                    from: 0.0; to: 1.0; decimals: 4
                                    onReleased: val => hyprlockState.updateConf("vibrancy_darkness", val.toFixed(4))
                                    onMoved: val => hyprlockState.vibrancy_darkness = val
                                }
                            }
                        }

                        QtObject {
                            id: hyprlockAssetsState
                            property int avatarTick: 0
                            property int bgTick: 0
                        }

                        FilePicker {
                            id: hyprlockAvatarPicker
                            pickerTitle: "Choose Lock Screen Avatar"
                            initialDir: Quickshell.env("HOME") + "/Pictures"
                            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                            onAccepted: (path) => {
                                pickHyprlockAvatarProc.command = [
                                    "bash", "-c",
                                    'mkdir -p ~/.config/hypr/assets && cp -- "$1" ~/.config/hypr/assets/user.jpg && echo ok',
                                    "bash", path
                                ]
                                pickHyprlockAvatarProc.running = true
                            }
                        }

                        FilePicker {
                            id: hyprlockBackgroundPicker
                            pickerTitle: "Choose Lock Screen Background"
                            initialDir: AppSettings.wallpaperDir
                            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                            onAccepted: (path) => {
                                pickHyprlockBackgroundProc.command = [
                                    "bash", "-c",
                                    'mkdir -p ~/.config/hypr/assets && cp -- "$1" ~/.config/hypr/assets/background.jpg && echo ok',
                                    "bash", path
                                ]
                                pickHyprlockBackgroundProc.running = true
                            }
                        }

                        Process {
                            id: pickHyprlockAvatarProc
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    if (this.text.trim() === "ok") hyprlockAssetsState.avatarTick++;
                                }
                            }
                        }

                        Process {
                            id: pickHyprlockBackgroundProc
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    if (this.text.trim() === "ok") hyprlockAssetsState.bgTick++;
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: settingsWin.currentSection === "about"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 140

                            Rectangle {
                                id: glowSource
                                anchors.centerIn: parent
                                width: 70
                                height: 70
                                radius: width / 2
                                color: Colors.primary
                                opacity: 0.4
                                visible: false
                            }

                            MultiEffect {
                                anchors.fill: glowSource
                                source: glowSource
                                blurEnabled: true
                                blur: 1.0
                                blurMax: 64
                                opacity: 0.2
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 112
                                height: 112
                                source: "../assets/logo.png"
                                sourceSize.width: 224
                                sourceSize.height: 224
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                            text: "aeonshell"
                            color: Colors.surfaceText
                            font.pixelSize: 30
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            Layout.preferredWidth: 380
                            horizontalAlignment: Text.AlignHCenter
                            text: "A Hyprland + Quickshell desktop that repaints itself\nfrom your wallpaper, powered by pywal."
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            lineHeight: 1.3
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 24
                            spacing: 8

                            Repeater {
                                model: ["Hyprland", "Quickshell", "awww", "pywal"]
                                delegate: Rectangle {
                                    radius: 8
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1
                                    implicitWidth: chipText.implicitWidth + 20
                                    implicitHeight: 28
                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: Colors.surfaceText
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 18
                            radius: 9
                            color: linkHover.hovered
                                ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16)
                                : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3)
                            border.width: 1
                            implicitWidth: linkRow.implicitWidth + 24
                            implicitHeight: 32
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: linkHover }
                            TapHandler {
                                onTapped: Qt.openUrlExternally("https://github.com/pzwt4cc/aeonshell")
                            }

                            RowLayout {
                                id: linkRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰊤"
                                    font.pixelSize: 13
                                    color: Colors.primary
                                }
                                Text {
                                    text: "View on GitHub"
                                    color: Colors.surfaceText
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 12
                            Layout.bottomMargin: 4
                            text: "MIT License"
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.4)
                            font.pixelSize: 11
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    component SettingsSlider: ColumnLayout {
        id: sroot
        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property int decimals: 2

        signal moved(real val)
        signal released(real val)

        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: sroot.label
                color: Colors.surfaceText
                font.pixelSize: 12
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                text: sroot.value.toFixed(sroot.decimals)
                color: Colors.primary
                font.pixelSize: 12
                font.bold: true
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 14

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
            }

            Rectangle {
                id: fillRect
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(parent.width, parent.width * (sroot.value - sroot.from) / (sroot.to - sroot.from)))
                height: 6
                radius: 3
                color: Colors.primary
            }
            
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, fillRect.width - width/2))
                width: sliderHover.hovered ? 12 : 10
                height: width
                radius: width/2
                color: "#ffffff"
                Behavior on width { NumberAnimation { duration: 100 } }
            }

            HoverHandler { id: sliderHover }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPositionChanged: (mouse) => {
                    let pct = Math.max(0, Math.min(1, mouse.x / width));
                    let val = sroot.from + pct * (sroot.to - sroot.from);
                    sroot.moved(val);
                }
                onReleased: (mouse) => {
                    let pct = Math.max(0, Math.min(1, mouse.x / width));
                    let val = sroot.from + pct * (sroot.to - sroot.from);
                    sroot.released(val);
                }
            }
        }
    }

    component SettingRow: RowLayout {
        id: rowRoot
        property string label: ""
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 10

        Text {
            text: rowRoot.label
            color: Colors.surfaceText
            font.pixelSize: 13
            Layout.fillWidth: true
        }

        Rectangle {
            id: switchTrack
            Layout.preferredWidth: 40
            Layout.preferredHeight: 22
            radius: 11
            color: rowRoot.checked
                ? Colors.primary
                : Qt.rgba(1, 1, 1, 0.14)
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: "white"
                y: 3
                x: rowRoot.checked ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            TapHandler {
                onTapped: rowRoot.toggled()
            }
        }
    }

    component NavItem: Rectangle {
        id: navRoot
        property string label: ""
        property string icon: ""
        property bool selected: false
        property string badge: ""
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 9
        color: navRoot.selected
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16)
            : (navHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler { id: navHover }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height - 12
            radius: 2
            color: Colors.primary
            opacity: navRoot.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 8

            Text {
                text: navRoot.icon
                font.pixelSize: 13
                Layout.preferredWidth: 16
                color: navRoot.enabled
                    ? (navRoot.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.7))
                    : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.3)
            }

            Text {
                text: navRoot.label
                color: navRoot.enabled
                    ? (navRoot.selected ? Colors.primary : Colors.surfaceText)
                    : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                font.pixelSize: 12
                font.bold: navRoot.selected
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                visible: navRoot.badge !== ""
                radius: 5
                color: Qt.rgba(1, 1, 1, 0.08)
                Layout.preferredHeight: 15
                implicitWidth: badgeText.implicitWidth + 8
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: navRoot.badge
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    font.pixelSize: 9
                }
            }
        }

        TapHandler {
            onTapped: navRoot.clicked()
        }
    }

    component PositionOption: Rectangle {
        id: optRoot
        property string label: ""
        property string pos: "top"
        property bool selected: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 96
        radius: 14
        color: optRoot.selected
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16)
            : (optHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        border.color: optRoot.selected ? Colors.primary : Qt.rgba(1, 1, 1, 0.14)
        border.width: optRoot.selected ? 1.5 : 1
        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler { id: optHover }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56
                height: 38
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.16)
                border.width: 1

                Rectangle {
                    radius: 2
                    color: optRoot.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                    anchors.margins: 4
                    anchors.top: optRoot.pos === "top" ? parent.top : undefined
                    anchors.bottom: optRoot.pos === "bottom" ? parent.bottom : undefined
                    anchors.left: optRoot.pos === "left" ? parent.left : undefined
                    anchors.right: optRoot.pos === "right" ? parent.right : undefined
                    anchors.horizontalCenter: (optRoot.pos === "top" || optRoot.pos === "bottom") ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: (optRoot.pos === "left" || optRoot.pos === "right") ? parent.verticalCenter : undefined
                    width: (optRoot.pos === "top" || optRoot.pos === "bottom") ? parent.width - 12 : 6
                    height: (optRoot.pos === "left" || optRoot.pos === "right") ? parent.height - 12 : 6
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: optRoot.label
                color: optRoot.selected ? Colors.primary : Colors.surfaceText
                font.pixelSize: 14
                font.bold: optRoot.selected
            }
        }

        TapHandler {
            onTapped: optRoot.clicked()
        }
    }
}