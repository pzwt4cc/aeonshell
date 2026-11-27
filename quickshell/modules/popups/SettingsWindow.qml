// SettingsWindow.qml

import "../"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Scope {
    id: root

    property string currentSection: _normalizeSection(ShellState.settingsSection)
    property bool confirmReset: false
    property bool editingWpDir: false
    property var targetScreen: _resolveActiveScreen()

    function _normalizeSection(sec) {
        if (sec === "launcher" || sec === "behavior" || sec === "about" || sec === "panel")
            return sec;
        if (sec === "bar")
            return "panel";
        if (sec === "keybinds" || sec === "hyprlock")
            return "behavior";
        return "panel";
    }

    function _resolveActiveScreen() {
        const mon = Hyprland.focusedMonitor;
        if (mon) {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i];
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function _close() {
        root.confirmReset = false;
        root.editingWpDir = false;
        ShellState.settingsWindowOpen = false;
    }

    onCurrentSectionChanged: {
        root.confirmReset = false;
        root.editingWpDir = false;
    }

    Timer {
        id: hideTimer
        interval: 210
    }

    Connections {
        target: ShellState
        function onSettingsWindowOpenChanged() {
            if (ShellState.settingsWindowOpen) {
                hideTimer.stop();
                root.targetScreen = root._resolveActiveScreen();
                root.confirmReset = false;
                root.editingWpDir = false;
                root.currentSection = root._normalizeSection(ShellState.settingsSection);
            } else {
                hideTimer.start();
            }
        }
        function onSettingsSectionChanged() {
            if (ShellState.settingsWindowOpen)
                root.currentSection = root._normalizeSection(ShellState.settingsSection);
        }
    }

    LazyLoader {
        id: overlayLoader
        active: ShellState.settingsWindowOpen || hideTimer.running

        PanelWindow {
            id: overlay

            property bool _animReady: false
            readonly property bool visualOpen: ShellState.settingsWindowOpen && overlay._animReady

            screen: root.targetScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusiveZone: 0
            color: "transparent"
            visible: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: ShellState.settingsWindowOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: ShellState.settingsWindowOpen ? null : emptyMask

            Region {
                id: emptyMask
            }

            Component.onCompleted: Qt.callLater(() => overlay._animReady = true)

            Shortcut {
                sequence: "Escape"
                enabled: ShellState.settingsWindowOpen
                onActivated: {
                    if (root.editingWpDir)
                        root.editingWpDir = false;
                    else
                        root._close();
                }
            }

            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, overlay.visualOpen ? 0.45 : 0.0)
                Behavior on color {
                    ColorAnimation {
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: root._close()
                }
            }

            Item {
                id: cardFrame
                anchors.centerIn: parent
                width: Math.min(660, parent.width - 48)
                height: Math.min(520, parent.height - 48)

                scale: overlay.visualOpen ? 1.0 : 0.96
                opacity: overlay.visualOpen ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutQuad
                    }
                }

                RectangularShadow {
                    anchors.fill: cardBg
                    anchors.margins: -8
                    radius: cardBg.radius + 8
                    color: Qt.rgba(0, 0, 0, 0.48)
                    blur: 28
                    spread: 0
                    offset: Qt.point(0, 10)
                }

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    radius: 22
                    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.97)
                    border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.28)
                    border.width: 1
                    clip: true

                    // Absorb all clicks inside the settings card so backdrop never closes on inner interaction
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        hoverEnabled: true
                        onPressed: mouse => mouse.accepted = true
                        onClicked: mouse => mouse.accepted = true
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 16

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 11
                                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16)
                                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒓"
                                    font.pixelSize: 18
                                    color: Colors.primary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: "Shell Settings"
                                    color: Colors.surfaceText
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                                Text {
                                    text: "Autonomous configuration · saved locally"
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                    font.pixelSize: 11
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 10
                                color: closeMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1) : "transparent"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.pixelSize: 14
                                    color: Colors.surfaceText
                                    opacity: closeMa.containsMouse ? 1.0 : 0.65
                                }
                                MouseArea {
                                    id: closeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._close()
                                }
                            }
                        }

                        // Segmented Section Tabs
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            radius: 13
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.05)
                            border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                TabPill {
                                    icon: "󰍜"
                                    label: "Panel & Theme"
                                    selected: root.currentSection === "panel"
                                    onClicked: root.currentSection = "panel"
                                }
                                TabPill {
                                    icon: "󰀻"
                                    label: "Launcher"
                                    selected: root.currentSection === "launcher"
                                    onClicked: root.currentSection = "launcher"
                                }
                                TabPill {
                                    icon: "󰂚"
                                    label: "Behavior"
                                    selected: root.currentSection === "behavior"
                                    onClicked: root.currentSection = "behavior"
                                }
                                TabPill {
                                    icon: "󰋼"
                                    label: "System"
                                    selected: root.currentSection === "about"
                                    onClicked: root.currentSection = "about"
                                }
                            }
                        }

                        // Active Section Content (single lazy Loader)
                        Loader {
                            id: sectionLoader
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: {
                                if (root.currentSection === "launcher")
                                    return launcherSectionComp;
                                if (root.currentSection === "behavior")
                                    return behaviorSectionComp;
                                if (root.currentSection === "about")
                                    return aboutSectionComp;
                                return panelSectionComp;
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 1: Panel & Theme
    // -------------------------------------------------------------------------
    Component {
        id: panelSectionComp
        Flickable {
            clip: true
            contentWidth: width
            contentHeight: panelCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: panelCol
                width: parent.width
                spacing: 12

                SectionCard {
                    title: "PANEL PLACEMENT"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        PlacementChip {
                            label: "Top"
                            pos: "top"
                            selected: AppSettings.barPosition === "top"
                            onClicked: AppSettings.barPosition = "top"
                        }
                        PlacementChip {
                            label: "Bottom"
                            pos: "bottom"
                            selected: AppSettings.barPosition === "bottom"
                            onClicked: AppSettings.barPosition = "bottom"
                        }
                        PlacementChip {
                            label: "Left"
                            pos: "left"
                            selected: AppSettings.barPosition === "left"
                            onClicked: AppSettings.barPosition = "left"
                        }
                        PlacementChip {
                            label: "Right"
                            pos: "right"
                            selected: AppSettings.barPosition === "right"
                            onClicked: AppSettings.barPosition = "right"
                        }
                    }
                }

                SectionCard {
                    title: "BAR MODULES & LAYOUT"

                    SwitchRow {
                        label: "Edge-to-edge layout"
                        subtitle: "Compact Hyprland gaps with square window corners"
                        checked: AppSettings.edgeToEdge
                        onToggled: AppSettings.edgeToEdge = !AppSettings.edgeToEdge
                    }

                    RowDivider {}

                    SwitchRow {
                        label: "Media player in bar"
                        subtitle: "Show active MPRIS track indicator"
                        checked: AppSettings.barShowPlayer
                        onToggled: AppSettings.barShowPlayer = !AppSettings.barShowPlayer
                    }

                    RowDivider {}

                    SwitchRow {
                        label: "System tray icons"
                        subtitle: "Display pinned and background tray apps"
                        checked: AppSettings.barShowTray
                        onToggled: AppSettings.barShowTray = !AppSettings.barShowTray
                    }
                }

                SectionCard {
                    title: "COLOR PALETTE"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Row {
                            spacing: 6
                            Repeater {
                                model: [Colors.background, Colors.surface, Colors.primary, Colors.secondary, Colors.error]
                                delegate: Rectangle {
                                    required property color modelData
                                    width: 22
                                    height: 22
                                    radius: 7
                                    color: modelData
                                    border.color: Qt.rgba(1, 1, 1, 0.22)
                                    border.width: 1
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: {
                                    if (Colors.themeSource === "matugen")
                                        return "Extracted via matugen";
                                    if (Colors.themeSource === "quantizer")
                                        return "Extracted via ColorQuantizer";
                                    if (Colors.themeSource === "cache")
                                        return "Loaded from local cache";
                                    return "Default palette";
                                }
                                color: Colors.surfaceText
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Text {
                                text: "Updates Quickshell, kitty, and cava on wallpaper change"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        ActionPill {
                            label: "Wallpapers"
                            icon: "󰸉"
                            accent: true
                            onClicked: {
                                root._close();
                                ShellState.openWallpaperRequested = true;
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 2: Launcher & Wallpapers
    // -------------------------------------------------------------------------
    Component {
        id: launcherSectionComp
        Flickable {
            id: launcherFlick
            clip: true
            contentWidth: width
            contentHeight: launcherCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            readonly property int hiddenCount: AppSettings.launcherHiddenApps.length ? AppSettings.launcherHiddenApps.split(",").filter(Boolean).length : 0

            ColumnLayout {
                id: launcherCol
                width: parent.width
                spacing: 12

                SectionCard {
                    title: "APP VIEW MODE"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ModeChip {
                            icon: "󰉹"
                            label: "List View"
                            selected: AppSettings.launcherViewMode !== "grid"
                            onClicked: AppSettings.launcherViewMode = "list"
                        }
                        ModeChip {
                            icon: "󰕰"
                            label: "Grid View"
                            selected: AppSettings.launcherViewMode === "grid"
                            onClicked: AppSettings.launcherViewMode = "grid"
                        }
                    }
                }

                SectionCard {
                    title: "WALLPAPER SOURCE"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Wallpapers directory"
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: AppSettings.wallpaperDir
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }

                        ActionPill {
                            label: root.editingWpDir ? "Cancel" : "Edit"
                            icon: root.editingWpDir ? "󰅖" : "󰏫"
                            onClicked: {
                                root.editingWpDir = !root.editingWpDir;
                                if (root.editingWpDir) {
                                    wpDirField.text = AppSettings.wallpaperDir;
                                    Qt.callLater(() => wpDirField.forceActiveFocus());
                                }
                            }
                        }

                        ActionPill {
                            label: "Default"
                            visible: AppSettings.wallpaperDir !== AppSettings.defaultWallpaperDir
                            onClicked: {
                                AppSettings.wallpaperDir = AppSettings.defaultWallpaperDir;
                                root.editingWpDir = false;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.editingWpDir
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 9
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                            border.color: wpDirField.activeFocus ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.14)
                            border.width: 1

                            TextField {
                                id: wpDirField
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.surfaceText
                                font.pixelSize: 12
                                background: Item {}
                                selectByMouse: true
                                placeholderText: "~/Pictures/Wallpapers"
                                placeholderTextColor: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.35)
                                Keys.onEscapePressed: event => {
                                    root.editingWpDir = false;
                                    event.accepted = true;
                                }
                                onAccepted: {
                                    const t = text.trim();
                                    if (t.length > 0)
                                        AppSettings.wallpaperDir = t;
                                    root.editingWpDir = false;
                                }
                            }
                        }

                        ActionPill {
                            label: "Save"
                            icon: "󰄬"
                            accent: true
                            onClicked: {
                                const t = wpDirField.text.trim();
                                if (t.length > 0)
                                    AppSettings.wallpaperDir = t;
                                root.editingWpDir = false;
                            }
                        }
                    }
                }

                SectionCard {
                    title: "HIDDEN APPLICATIONS"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: launcherFlick.hiddenCount === 0 ? "No hidden apps" : launcherFlick.hiddenCount + (launcherFlick.hiddenCount === 1 ? " hidden app" : " hidden apps")
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: "Use >hidden-apps in launcher to manage individual apps"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        ActionPill {
                            label: "Restore all"
                            icon: "󰜉"
                            enabled: launcherFlick.hiddenCount > 0
                            opacity: launcherFlick.hiddenCount > 0 ? 1.0 : 0.4
                            onClicked: AppSettings.launcherHiddenApps = ""
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 3: Behavior (Notifications & Media)
    // -------------------------------------------------------------------------
    Component {
        id: behaviorSectionComp
        Flickable {
            id: behaviorFlick
            clip: true
            contentWidth: width
            contentHeight: behaviorCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            readonly property var defaultSink: Pipewire.defaultAudioSink
            readonly property bool sinkMuted: !!(defaultSink && defaultSink.audio && defaultSink.audio.muted)
            readonly property int sinkVolPct: (defaultSink && defaultSink.audio) ? Math.round(Math.min(1.5, defaultSink.audio.volume) * 100) : 0

            PwObjectTracker {
                objects: behaviorFlick.defaultSink ? [behaviorFlick.defaultSink] : []
            }

            ColumnLayout {
                id: behaviorCol
                width: parent.width
                spacing: 12

                SectionCard {
                    title: "NOTIFICATIONS"

                    SwitchRow {
                        label: "Do Not Disturb"
                        subtitle: "Silence popups and mute chat app streams"
                        checked: NotificationService.dnd
                        onToggled: NotificationService.dnd = !NotificationService.dnd
                    }

                    RowDivider {}

                    SwitchRow {
                        label: "Group by application"
                        subtitle: "Cluster notifications per source in Notification Center"
                        checked: AppSettings.groupNotificationsBySource
                        onToggled: AppSettings.groupNotificationsBySource = !AppSettings.groupNotificationsBySource
                    }

                    RowDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Notification history"
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: NotificationService.history.length + " stored · " + NotificationService.unreadCount + " unread"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 11
                            }
                        }

                        ActionPill {
                            label: "Clear all"
                            icon: "󰎟"
                            enabled: NotificationService.history.length > 0
                            opacity: NotificationService.history.length > 0 ? 1.0 : 0.4
                            onClicked: NotificationService.clearAll()
                        }
                    }
                }

                SectionCard {
                    title: "AUDIO & MEDIA"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: behaviorFlick.defaultSink ? (behaviorFlick.defaultSink.description || behaviorFlick.defaultSink.nickname || behaviorFlick.defaultSink.name || "Output device") : "No output device"
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: behaviorFlick.sinkMuted ? "Muted" : ("Master output volume: " + behaviorFlick.sinkVolPct + "%")
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 11
                            }
                        }

                        ActionPill {
                            label: behaviorFlick.sinkMuted ? "Unmute" : "Mute"
                            icon: behaviorFlick.sinkMuted ? "󰖁" : "󰕾"
                            enabled: behaviorFlick.defaultSink !== null && behaviorFlick.defaultSink.audio !== null
                            onClicked: {
                                if (behaviorFlick.defaultSink && behaviorFlick.defaultSink.audio)
                                    behaviorFlick.defaultSink.audio.muted = !behaviorFlick.defaultSink.audio.muted;
                            }
                        }
                    }

                    RowDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: MprisService.active ? (MprisService.trackTitle || "Active player") : "No active media player"
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: MprisService.active ? ((MprisService.playerName || "MPRIS") + (MprisService.trackArtist ? " · " + MprisService.trackArtist : "")) : "Start playback in any MPRIS player"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        ActionPill {
                            label: MprisService.isPlaying ? "Pause" : "Play"
                            icon: MprisService.isPlaying ? "󰏤" : "󰐊"
                            enabled: MprisService.active
                            opacity: MprisService.active ? 1.0 : 0.4
                            onClicked: MprisService.playPause()
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 4: System & About
    // -------------------------------------------------------------------------
    Component {
        id: aboutSectionComp
        Flickable {
            clip: true
            contentWidth: width
            contentHeight: aboutCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: aboutCol
                width: parent.width
                spacing: 12

                SectionCard {
                    title: "AUTONOMOUS STORAGE"

                    InfoLine {
                        label: "Shell settings"
                        value: AppSettings.confPath
                    }
                    RowDivider {}
                    InfoLine {
                        label: "Palette cache"
                        value: Colors.cacheJsonPath
                    }
                    RowDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Reset shell preferences"
                                color: Colors.surfaceText
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: "Restores bar position, layout, view mode, and wallpaper path"
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                font.pixelSize: 11
                            }
                        }

                        ActionPill {
                            label: root.confirmReset ? "Confirm reset" : "Reset"
                            icon: "󰑓"
                            accent: root.confirmReset
                            onClicked: {
                                if (!root.confirmReset) {
                                    root.confirmReset = true;
                                } else {
                                    AppSettings.resetDefaults();
                                    root.confirmReset = false;
                                }
                            }
                        }
                    }
                }

                SectionCard {
                    title: "ABOUT AEONSHELL"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 16
                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.25)
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 42
                                height: 42
                                source: "../../assets/logo.svg"
                                sourceSize: Qt.size(84, 84)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "aeonshell"
                                color: Colors.surfaceText
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                text: "Autonomous Quickshell + Hyprland desktop with matugen & ColorQuantizer theming."
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        ActionPill {
                            label: "GitHub"
                            icon: "󰊤"
                            onClicked: Qt.openUrlExternally("https://github.com/pzwt4cc/aeonshell")
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: ["Quickshell", "Hyprland", "PipeWire", "matugen", "ColorQuantizer", "awww", "mpvpaper"]
                            delegate: Rectangle {
                                required property string modelData
                                radius: 7
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
                                border.width: 1
                                implicitWidth: chipTxt.implicitWidth + 16
                                implicitHeight: 24

                                Text {
                                    id: chipTxt
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.85)
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Reusable Lightweight Components
    // -------------------------------------------------------------------------
    component SectionCard: Rectangle {
        id: cardRoot
        property string title: ""
        default property alias content: cardCol.data

        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + 28
        radius: 16
        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.045)
        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
        border.width: 1

        ColumnLayout {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                visible: cardRoot.title !== ""
                text: cardRoot.title
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }
        }
    }

    component RowDivider: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
    }

    component SwitchRow: RowLayout {
        id: swRow
        property string label: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled

        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: swRow.label
                color: Colors.surfaceText
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                visible: swRow.subtitle !== ""
                text: swRow.subtitle
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 24
            radius: 12
            color: swRow.checked ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.14)
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#ffffff"
                y: 3
                x: swRow.checked ? parent.width - width - 3 : 3
                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: swRow.toggled()
            }
        }
    }

    component TabPill: Rectangle {
        id: tabRoot
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal clicked

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 9
        color: tabRoot.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.18) : (tabMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent")
        border.color: tabRoot.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : "transparent"
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: tabRoot.icon
                font.pixelSize: 13
                color: tabRoot.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
            }
            Text {
                text: tabRoot.label
                font.pixelSize: 12
                font.bold: tabRoot.selected
                color: tabRoot.selected ? Colors.primary : Colors.surfaceText
            }
        }

        MouseArea {
            id: tabMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tabRoot.clicked()
        }
    }

    component PlacementChip: Rectangle {
        id: pChip
        property string label: ""
        property string pos: "top"
        property bool selected: false
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 68
        radius: 12
        color: pChip.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16) : (pMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.03))
        border.color: pChip.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
        border.width: pChip.selected ? 1.5 : 1
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 36
                height: 24
                radius: 5
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                border.width: 1

                Rectangle {
                    radius: 2
                    color: pChip.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                    anchors.margins: 3
                    anchors.top: pChip.pos === "top" ? parent.top : undefined
                    anchors.bottom: pChip.pos === "bottom" ? parent.bottom : undefined
                    anchors.left: pChip.pos === "left" ? parent.left : undefined
                    anchors.right: pChip.pos === "right" ? parent.right : undefined
                    anchors.horizontalCenter: (pChip.pos === "top" || pChip.pos === "bottom") ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: (pChip.pos === "left" || pChip.pos === "right") ? parent.verticalCenter : undefined
                    width: (pChip.pos === "top" || pChip.pos === "bottom") ? parent.width - 8 : 5
                    height: (pChip.pos === "left" || pChip.pos === "right") ? parent.height - 8 : 4
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: pChip.label
                color: pChip.selected ? Colors.primary : Colors.surfaceText
                font.pixelSize: 12
                font.bold: pChip.selected
            }
        }

        MouseArea {
            id: pMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pChip.clicked()
        }
    }

    component ModeChip: Rectangle {
        id: mChip
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        radius: 11
        color: mChip.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16) : (mMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.03))
        border.color: mChip.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.1)
        border.width: mChip.selected ? 1.5 : 1
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: mChip.icon
                font.pixelSize: 15
                color: mChip.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
            }
            Text {
                text: mChip.label
                font.pixelSize: 13
                font.bold: mChip.selected
                color: mChip.selected ? Colors.primary : Colors.surfaceText
            }
        }

        MouseArea {
            id: mMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mChip.clicked()
        }
    }

    component ActionPill: Rectangle {
        id: actPill
        property string label: ""
        property string icon: ""
        property bool accent: false
        signal clicked

        implicitWidth: pillRow.implicitWidth + 20
        Layout.preferredHeight: 30
        radius: 9
        color: actPill.accent ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, actMa.containsMouse ? 0.28 : 0.18) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, actMa.containsMouse ? 0.12 : 0.07)
        border.color: actPill.accent ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.45) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12)
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: actPill.icon !== ""
                text: actPill.icon
                font.pixelSize: 13
                color: actPill.accent ? Colors.primary : Colors.surfaceText
            }
            Text {
                text: actPill.label
                font.pixelSize: 12
                font.bold: true
                color: actPill.accent ? Colors.primary : Colors.surfaceText
            }
        }

        MouseArea {
            id: actMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actPill.clicked()
        }
    }

    component InfoLine: RowLayout {
        id: infoLine
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 10
        Text {
            text: infoLine.label
            color: Colors.surfaceText
            font.pixelSize: 12
            font.bold: true
            Layout.preferredWidth: 110
        }
        Text {
            text: infoLine.value
            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
            font.pixelSize: 11
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignRight
            Layout.fillWidth: true
        }
    }
}
