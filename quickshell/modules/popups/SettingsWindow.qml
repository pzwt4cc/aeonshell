// SettingsWindow.qml

pragma ComponentBehavior: Bound

import "../"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
    property bool hasCustomPos: false
    property real cardX: 0
    property real cardY: 0

    function _normalizeSection(sec) {
        if (sec === "appearance" || sec === "panel" || sec === "launcher" || sec === "language" || sec === "behavior" || sec === "about")
            return sec;
        if (sec === "bar")
            return "panel";
        if (sec === "media" || sec === "keybinds" || sec === "hyprlock")
            return "behavior";
        if (sec === "system")
            return "about";
        return "appearance";
    }

    function _sectionIcon(sec) {
        if (sec === "panel")
            return "󰍜";
        if (sec === "launcher")
            return "󰀻";
        if (sec === "language")
            return "󰗊";
        if (sec === "behavior")
            return "󰂚";
        if (sec === "about")
            return "󰋼";
        return "󰏘";
    }

    function _sectionTitle(sec) {
        if (sec === "panel")
            return Lang.t("settings.secPanelTitle");
        if (sec === "launcher")
            return Lang.t("settings.secLauncherTitle");
        if (sec === "language")
            return Lang.t("settings.secLanguageTitle");
        if (sec === "behavior")
            return Lang.t("settings.secBehaviorTitle");
        if (sec === "about")
            return Lang.t("settings.secAboutTitle");
        return Lang.t("settings.secAppearanceTitle");
    }

    function _sectionSubtitle(sec) {
        if (sec === "panel")
            return Lang.t("settings.secPanelSub");
        if (sec === "launcher")
            return Lang.t("settings.secLauncherSub");
        if (sec === "language")
            return Lang.t("settings.secLanguageSub");
        if (sec === "behavior")
            return Lang.t("settings.secBehaviorSub");
        if (sec === "about")
            return Lang.t("settings.secAboutSub");
        return Lang.t("settings.secAppearanceSub");
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
                root.hasCustomPos = false;
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

            mask: ShellState.settingsWindowOpen ? cardMask : emptyMask

            Region {
                id: emptyMask
            }

            Region {
                id: cardMask
                item: cardFrame
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

            Item {
                id: overlayCanvas
                anchors.fill: parent

                function beginDrag() {
                    if (!root.hasCustomPos) {
                        root.cardX = cardFrame.x;
                        root.cardY = cardFrame.y;
                        root.hasCustomPos = true;
                    }
                }

                function moveCardTo(newX, newY) {
                    const maxX = Math.max(0, overlayCanvas.width - cardFrame.width);
                    const maxY = Math.max(0, overlayCanvas.height - cardFrame.height);
                    root.cardX = Math.max(0, Math.min(maxX, Math.round(newX)));
                    root.cardY = Math.max(0, Math.min(maxY, Math.round(newY)));
                }

                Item {
                    id: cardFrame
                    width: Math.round(Math.min(overlayCanvas.width - 48, Math.max(760, overlayCanvas.width * 0.58)))
                    height: Math.round(Math.min(overlayCanvas.height - 48, Math.max(540, overlayCanvas.height * 0.62)))
                    x: root.hasCustomPos ? Math.min(root.cardX, Math.max(0, overlayCanvas.width - width)) : Math.round((overlayCanvas.width - width) / 2)
                    y: root.hasCustomPos ? Math.min(root.cardY, Math.max(0, overlayCanvas.height - height)) : Math.round((overlayCanvas.height - height) / 2)

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

                    Rectangle {
                        id: cardBg
                        anchors.fill: parent
                        radius: 20
                        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, AppSettings.popupOpacity)
                        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.30)
                        border.width: 1
                        clip: true

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Left Sidebar Navigation
                            Rectangle {
                                Layout.preferredWidth: Math.round(Math.min(252, Math.max(216, cardBg.width * 0.24)))
                                Layout.fillHeight: true
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.028)

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // Brand Header (drag handle)
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 68

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            hoverEnabled: true
                                            preventStealing: true
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            property real startMouseX: 0
                                            property real startMouseY: 0
                                            property real startCardX: 0
                                            property real startCardY: 0
                                            onPressed: mouse => {
                                                const pt = mapToItem(overlayCanvas, mouse.x, mouse.y);
                                                startMouseX = pt.x;
                                                startMouseY = pt.y;
                                                overlayCanvas.beginDrag();
                                                startCardX = root.cardX;
                                                startCardY = root.cardY;
                                            }
                                            onPositionChanged: mouse => {
                                                if (!pressed)
                                                    return;
                                                const pt = mapToItem(overlayCanvas, mouse.x, mouse.y);
                                                overlayCanvas.moveCardTo(startCardX + (pt.x - startMouseX), startCardY + (pt.y - startMouseY));
                                            }
                                            onDoubleClicked: root.hasCustomPos = false
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 36
                                                Layout.preferredHeight: 36
                                                radius: 10
                                                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14)
                                                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.26)
                                                border.width: 1

                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 22
                                                    height: 22
                                                    source: "../../assets/logo.svg"
                                                    sourceSize: Qt.size(44, 44)
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: Lang.t("settings.subtitle")
                                                    color: Colors.surfaceText
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: Lang.t("settings.title")
                                                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 1
                                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                                        }
                                    }

                                    // Sidebar Section List
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.margins: 14
                                        spacing: 4

                                        SidebarGroupLabel {
                                            text: Lang.t("settings.groupInterface")
                                        }

                                        SidebarTab {
                                            icon: "󰏘"
                                            label: Lang.t("settings.tabAppearance")
                                            selected: root.currentSection === "appearance"
                                            onClicked: root.currentSection = "appearance"
                                        }
                                        SidebarTab {
                                            icon: "󰍜"
                                            label: Lang.t("settings.tabPanel")
                                            selected: root.currentSection === "panel"
                                            onClicked: root.currentSection = "panel"
                                        }
                                        SidebarTab {
                                            icon: "󰀻"
                                            label: Lang.t("settings.tabLauncher")
                                            selected: root.currentSection === "launcher"
                                            onClicked: root.currentSection = "launcher"
                                        }
                                        SidebarTab {
                                            icon: "󰗊"
                                            label: Lang.t("settings.tabLanguage")
                                            selected: root.currentSection === "language"
                                            onClicked: root.currentSection = "language"
                                        }

                                        SidebarGroupLabel {
                                            Layout.topMargin: 10
                                            text: Lang.t("settings.groupSystem")
                                        }

                                        SidebarTab {
                                            icon: "󰂚"
                                            label: Lang.t("settings.tabBehavior")
                                            selected: root.currentSection === "behavior"
                                            onClicked: root.currentSection = "behavior"
                                        }
                                        SidebarTab {
                                            icon: "󰋼"
                                            label: Lang.t("settings.tabAbout")
                                            selected: root.currentSection === "about"
                                            onClicked: root.currentSection = "about"
                                        }

                                        Item {
                                            Layout.fillHeight: true
                                        }

                                        // Bottom Palette Status Pill
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 54
                                            radius: 12
                                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04)
                                            border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                            border.width: 1

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                anchors.topMargin: 8
                                                anchors.bottomMargin: 8
                                                spacing: 6

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Text {
                                                        text: Lang.t("settings.activePalette")
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        font.letterSpacing: 0.9
                                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.45)
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: Colors.themeSource
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        color: Colors.primary
                                                    }
                                                }

                                                Row {
                                                    spacing: 6
                                                    Repeater {
                                                        model: [Colors.background, Colors.surface, Colors.primary, Colors.secondary, Colors.error]
                                                        delegate: Rectangle {
                                                            required property color modelData
                                                            width: 16
                                                            height: 16
                                                            radius: 5
                                                            color: modelData
                                                            border.color: Qt.rgba(1, 1, 1, 0.22)
                                                            border.width: 1
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Vertical Divider
                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                            }

                            // Right Content Pane
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 0

                                // Top Content Header (drag handle)
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 68

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        property real startMouseX: 0
                                        property real startMouseY: 0
                                        property real startCardX: 0
                                        property real startCardY: 0
                                        onPressed: mouse => {
                                            const pt = mapToItem(overlayCanvas, mouse.x, mouse.y);
                                            startMouseX = pt.x;
                                            startMouseY = pt.y;
                                            overlayCanvas.beginDrag();
                                            startCardX = root.cardX;
                                            startCardY = root.cardY;
                                        }
                                        onPositionChanged: mouse => {
                                            if (!pressed)
                                                return;
                                            const pt = mapToItem(overlayCanvas, mouse.x, mouse.y);
                                            overlayCanvas.moveCardTo(startCardX + (pt.x - startMouseX), startCardY + (pt.y - startMouseY));
                                        }
                                        onDoubleClicked: root.hasCustomPos = false
                                    }

                                    // Subtle top drag pill indicator
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.topMargin: 6
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 36
                                        height: 3
                                        radius: 1.5
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.18)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 24
                                        anchors.rightMargin: 20
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 34
                                            radius: 10
                                            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                                            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.22)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: root._sectionIcon(root.currentSection)
                                                font.pixelSize: 16
                                                color: Colors.primary
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: root._sectionTitle(root.currentSection)
                                                color: Colors.surfaceText
                                                font.pixelSize: 18
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: root._sectionSubtitle(root.currentSection)
                                                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Rectangle {
                                            visible: root.hasCustomPos
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 9
                                            color: recenterMa.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.16) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04)
                                            border.color: recenterMa.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.35) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                            border.width: 1
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 120
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰘖"
                                                font.pixelSize: 14
                                                color: recenterMa.containsMouse ? Colors.primary : Colors.surfaceText
                                                opacity: recenterMa.containsMouse ? 1.0 : 0.7
                                            }
                                            MouseArea {
                                                id: recenterMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.hasCustomPos = false
                                            }

                                            ToolTip.visible: recenterMa.containsMouse
                                            ToolTip.delay: 400
                                            ToolTip.text: Lang.t("settings.recenterTooltip")
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 9
                                            color: closeMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04)
                                            border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
                                            border.width: 1
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
                                                opacity: closeMa.containsMouse ? 1.0 : 0.7
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

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                                    }
                                }

                                // Active Section Content
                                Loader {
                                    id: sectionLoader
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    sourceComponent: {
                                        if (root.currentSection === "panel")
                                            return panelSectionComp;
                                        if (root.currentSection === "launcher")
                                            return launcherSectionComp;
                                        if (root.currentSection === "language")
                                            return languageSectionComp;
                                        if (root.currentSection === "behavior")
                                            return behaviorSectionComp;
                                        if (root.currentSection === "about")
                                            return aboutSectionComp;
                                        return appearanceSectionComp;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 1: Appearance (Palette & Transparency)
    // -------------------------------------------------------------------------
    Component {
        id: appearanceSectionComp
        SectionScroll {
            SectionCard {
                title: Lang.t("settings.paletteCard")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Row {
                        spacing: 7
                        Repeater {
                            model: [Colors.background, Colors.surface, Colors.primary, Colors.secondary, Colors.error]
                            delegate: Rectangle {
                                required property color modelData
                                width: 28
                                height: 28
                                radius: 8
                                color: modelData
                                border.color: Qt.rgba(1, 1, 1, 0.22)
                                border.width: 1
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: {
                                if (Colors.themeSource === "matugen")
                                    return Lang.t("settings.paletteMatugen");
                                if (Colors.themeSource === "quantizer")
                                    return Lang.t("settings.paletteQuantizer");
                                if (Colors.themeSource === "cache")
                                    return Lang.t("settings.paletteCache");
                                return Lang.t("settings.paletteDefault");
                            }
                            color: Colors.surfaceText
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: Lang.t("settings.paletteSub")
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ActionPill {
                        label: Lang.t("settings.wallpapersBtn")
                        icon: "󰸉"
                        accent: true
                        onClicked: {
                            root._close();
                            ShellState.openWallpaperRequested = true;
                        }
                    }
                }
            }

            SectionCard {
                title: Lang.t("settings.transparencyCard")

                SliderRow {
                    label: Lang.t("settings.barOpacity")
                    subtitle: Lang.t("settings.barOpacitySub")
                    value: AppSettings.barOpacity
                    minValue: 0.25
                    maxValue: 1.0
                    onValueEdited: val => AppSettings.barOpacity = val
                }

                RowDivider {}

                SliderRow {
                    label: Lang.t("settings.popupOpacity")
                    subtitle: Lang.t("settings.popupOpacitySub")
                    value: AppSettings.popupOpacity
                    minValue: 0.40
                    maxValue: 1.0
                    onValueEdited: val => AppSettings.popupOpacity = val
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 2: Bar & Panel
    // -------------------------------------------------------------------------
    Component {
        id: panelSectionComp
        SectionScroll {
            SectionCard {
                title: Lang.t("settings.placementCard")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    PlacementChip {
                        label: Lang.t("settings.posTop")
                        pos: "top"
                        selected: AppSettings.barPosition === "top"
                        onClicked: AppSettings.barPosition = "top"
                    }
                    PlacementChip {
                        label: Lang.t("settings.posBottom")
                        pos: "bottom"
                        selected: AppSettings.barPosition === "bottom"
                        onClicked: AppSettings.barPosition = "bottom"
                    }
                    PlacementChip {
                        label: Lang.t("settings.posLeft")
                        pos: "left"
                        selected: AppSettings.barPosition === "left"
                        onClicked: AppSettings.barPosition = "left"
                    }
                    PlacementChip {
                        label: Lang.t("settings.posRight")
                        pos: "right"
                        selected: AppSettings.barPosition === "right"
                        onClicked: AppSettings.barPosition = "right"
                    }
                }
            }

            SectionCard {
                title: Lang.t("settings.modulesCard")

                SwitchRow {
                    label: Lang.t("settings.edgeToEdge")
                    subtitle: Lang.t("settings.edgeToEdgeSub")
                    checked: AppSettings.edgeToEdge
                    onToggled: AppSettings.edgeToEdge = !AppSettings.edgeToEdge
                }

                RowDivider {}

                SwitchRow {
                    label: Lang.t("settings.mediaInBar")
                    subtitle: Lang.t("settings.mediaInBarSub")
                    checked: AppSettings.barShowPlayer
                    onToggled: AppSettings.barShowPlayer = !AppSettings.barShowPlayer
                }

                RowDivider {}

                SwitchRow {
                    label: Lang.t("settings.trayIcons")
                    subtitle: Lang.t("settings.trayIconsSub")
                    checked: AppSettings.barShowTray
                    onToggled: AppSettings.barShowTray = !AppSettings.barShowTray
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 3: Launcher & Wallpapers
    // -------------------------------------------------------------------------
    Component {
        id: launcherSectionComp
        SectionScroll {
            id: launcherScroll
            readonly property int hiddenCount: AppSettings.launcherHiddenApps.length ? AppSettings.launcherHiddenApps.split(",").filter(Boolean).length : 0

            SectionCard {
                title: Lang.t("settings.viewModeCard")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ModeChip {
                        icon: "󰉹"
                        label: Lang.t("settings.listView")
                        selected: AppSettings.launcherViewMode !== "grid"
                        onClicked: AppSettings.launcherViewMode = "list"
                    }
                    ModeChip {
                        icon: "󰕰"
                        label: Lang.t("settings.gridView")
                        selected: AppSettings.launcherViewMode === "grid"
                        onClicked: AppSettings.launcherViewMode = "grid"
                    }
                }
            }

            SectionCard {
                title: Lang.t("settings.wpSourceCard")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: Lang.t("settings.wpDirLabel")
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
                        label: root.editingWpDir ? Lang.t("common.cancel") : Lang.t("common.edit")
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
                        label: Lang.t("common.default")
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
                        Layout.preferredHeight: 36
                        radius: 10
                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)
                        border.color: wpDirField.activeFocus ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.14)
                        border.width: 1

                        TextField {
                            id: wpDirField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
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
                                const val = text.trim();
                                if (val.length > 0)
                                    AppSettings.wallpaperDir = val;
                                root.editingWpDir = false;
                            }
                        }
                    }

                    ActionPill {
                        label: Lang.t("common.save")
                        icon: "󰄬"
                        accent: true
                        onClicked: {
                            const val = wpDirField.text.trim();
                            if (val.length > 0)
                                AppSettings.wallpaperDir = val;
                            root.editingWpDir = false;
                        }
                    }
                }
            }

            SectionCard {
                title: Lang.t("settings.hiddenAppsCard")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: launcherScroll.hiddenCount === 0 ? Lang.t("settings.hiddenAppsNone") : Lang.tp("settings.hiddenAppsCount", launcherScroll.hiddenCount)
                            color: Colors.surfaceText
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: Lang.t("settings.hiddenAppsSub")
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ActionPill {
                        label: Lang.t("settings.restoreAll")
                        icon: "󰜉"
                        enabled: launcherScroll.hiddenCount > 0
                        opacity: launcherScroll.hiddenCount > 0 ? 1.0 : 0.4
                        onClicked: AppSettings.launcherHiddenApps = ""
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 4: Language
    // -------------------------------------------------------------------------
    Component {
        id: languageSectionComp
        SectionScroll {
            SectionCard {
                title: Lang.t("settings.languageCard")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: Lang.availableLanguages
                        delegate: Rectangle {
                            id: langCard
                            required property var modelData
                            readonly property bool selected: AppSettings.language === langCard.modelData.code

                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            radius: 12
                            color: langCard.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14) : (langMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.065) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.03))
                            border.color: langCard.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.7) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.09)
                            border.width: langCard.selected ? 1.5 : 1

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

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    radius: 10
                                    color: langCard.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.22) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.07)

                                    Text {
                                        anchors.centerIn: parent
                                        text: langCard.modelData.shortLabel
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: langCard.selected ? Colors.primary : Colors.surfaceText
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: langCard.modelData.label
                                        color: langCard.selected ? Colors.primary : Colors.surfaceText
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                    Text {
                                        text: langCard.modelData.region
                                        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.5)
                                        font.pixelSize: 11
                                    }
                                }

                                Rectangle {
                                    visible: langCard.selected
                                    implicitWidth: activeRow.implicitWidth + 16
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
                                    border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4)
                                    border.width: 1

                                    RowLayout {
                                        id: activeRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text {
                                            text: "󰄬"
                                            font.pixelSize: 12
                                            color: Colors.primary
                                        }
                                        Text {
                                            text: Lang.t("settings.langActive")
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Colors.primary
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: langMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AppSettings.language = langCard.modelData.code
                            }
                        }
                    }
                }
            }

            SectionCard {
                title: Lang.t("settings.langPreviewCard")

                InfoLine {
                    label: Lang.t("settings.langSampleDate")
                    value: Qt.formatDate(new Date(), AppSettings.language === "ru" ? "dddd, d MMMM yyyy" : "dddd, MMMM d, yyyy", AppSettings.qtLocale)
                }

                RowDivider {}

                Text {
                    text: Lang.t("settings.langNote")
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 5: Notifications & Media (Behavior)
    // -------------------------------------------------------------------------
    Component {
        id: behaviorSectionComp
        SectionScroll {
            id: behaviorScroll

            readonly property var defaultSink: Pipewire.defaultAudioSink
            readonly property bool sinkMuted: !!(defaultSink && defaultSink.audio && defaultSink.audio.muted)
            readonly property int sinkVolPct: (defaultSink && defaultSink.audio) ? Math.round(Math.min(1.5, defaultSink.audio.volume) * 100) : 0

            PwObjectTracker {
                objects: behaviorScroll.defaultSink ? [behaviorScroll.defaultSink] : []
            }

            SectionCard {
                title: Lang.t("settings.notificationsCard")

                SwitchRow {
                    label: Lang.t("settings.dndLabel")
                    subtitle: Lang.t("settings.dndSub")
                    checked: NotificationService.dnd
                    onToggled: NotificationService.dnd = !NotificationService.dnd
                }

                RowDivider {}

                SwitchRow {
                    label: Lang.t("settings.groupByApp")
                    subtitle: Lang.t("settings.groupByAppSub")
                    checked: AppSettings.groupNotificationsBySource
                    onToggled: AppSettings.groupNotificationsBySource = !AppSettings.groupNotificationsBySource
                }

                RowDivider {}

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: Lang.t("settings.notifHistory")
                            color: Colors.surfaceText
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: Lang.t("settings.notifHistorySub", {
                                stored: NotificationService.history.length,
                                unread: NotificationService.unreadCount
                            })
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                            font.pixelSize: 11
                        }
                    }

                    ActionPill {
                        label: Lang.t("common.clearAll")
                        icon: "󰎟"
                        enabled: NotificationService.history.length > 0
                        opacity: NotificationService.history.length > 0 ? 1.0 : 0.4
                        onClicked: NotificationService.clearAll()
                    }
                }
            }

            SectionCard {
                title: Lang.t("settings.audioMediaCard")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: behaviorScroll.defaultSink ? (behaviorScroll.defaultSink.description || behaviorScroll.defaultSink.nickname || behaviorScroll.defaultSink.name || Lang.t("settings.outputDevice")) : Lang.t("settings.noOutputDevice")
                            color: Colors.surfaceText
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: behaviorScroll.sinkMuted ? Lang.t("audio.muted") : Lang.t("settings.masterVol", {
                                pct: behaviorScroll.sinkVolPct
                            })
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                            font.pixelSize: 11
                        }
                    }

                    ActionPill {
                        label: behaviorScroll.sinkMuted ? Lang.t("settings.unmute") : Lang.t("settings.mute")
                        icon: behaviorScroll.sinkMuted ? "󰖁" : "󰕾"
                        enabled: behaviorScroll.defaultSink !== null && behaviorScroll.defaultSink.audio !== null
                        onClicked: {
                            if (behaviorScroll.defaultSink && behaviorScroll.defaultSink.audio)
                                behaviorScroll.defaultSink.audio.muted = !behaviorScroll.defaultSink.audio.muted;
                        }
                    }
                }

                RowDivider {}

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: MprisService.active ? (MprisService.trackTitle || Lang.t("settings.activePlayer")) : Lang.t("settings.noActivePlayer")
                            color: Colors.surfaceText
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: MprisService.active ? ((MprisService.playerName || "MPRIS") + (MprisService.trackArtist ? " · " + MprisService.trackArtist : "")) : Lang.t("settings.startPlayback")
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ActionPill {
                        label: MprisService.isPlaying ? Lang.t("settings.pause") : Lang.t("settings.play")
                        icon: MprisService.isPlaying ? "󰏤" : "󰐊"
                        enabled: MprisService.active
                        opacity: MprisService.active ? 1.0 : 0.4
                        onClicked: MprisService.playPause()
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Section 6: System & About
    // -------------------------------------------------------------------------
    Component {
        id: aboutSectionComp
        SectionScroll {
            SectionCard {
                title: Lang.t("settings.storageCard")

                InfoLine {
                    label: Lang.t("settings.userDataDir")
                    value: AppSettings.configDir
                }
                RowDivider {}
                InfoLine {
                    label: Lang.t("settings.shellSettingsPath")
                    value: AppSettings.confPath
                }
                RowDivider {}
                InfoLine {
                    label: Lang.t("settings.paletteCachePath")
                    value: Colors.cacheJsonPath
                }
                RowDivider {}

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: Lang.t("settings.resetTitle")
                            color: Colors.surfaceText
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: Lang.t("settings.resetSub")
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    ActionPill {
                        label: root.confirmReset ? Lang.t("common.confirmReset") : Lang.t("common.reset")
                        icon: "󰑓"
                        danger: root.confirmReset
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
                title: Lang.t("settings.aboutCard")

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
                            text: Lang.t("settings.aboutDesc")
                            color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    ActionPill {
                        label: Lang.t("settings.github")
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
                            id: techChip
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
                                text: techChip.modelData
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

    // -------------------------------------------------------------------------
    // Reusable Lightweight Components
    // -------------------------------------------------------------------------
    component SectionScroll: Item {
        id: scrollWrap
        default property alias content: innerCol.data

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 22
            clip: true
            contentWidth: width
            contentHeight: innerCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            readonly property bool scrollable: contentHeight > height + 1

            ScrollBar.vertical: ScrollBar {
                id: secBar
                policy: flick.scrollable ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                interactive: true
                width: 5
                background: Item {}
                contentItem: Rectangle {
                    implicitWidth: 5
                    radius: 2.5
                    color: secBar.pressed ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, secBar.hovered ? 0.45 : 0.24)
                }
            }

            ColumnLayout {
                id: innerCol
                readonly property real availW: flick.width - (flick.scrollable ? 14 : 0)
                width: Math.min(availW, 860)
                x: Math.round((availW - width) / 2)
                spacing: 14
            }
        }
    }

    component SidebarGroupLabel: Text {
        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.42)
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.0
        Layout.leftMargin: 10
        Layout.bottomMargin: 2
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    component SidebarTab: Rectangle {
        id: sTab
        property string icon: ""
        property string label: ""
        property bool selected: false
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 10
        color: sTab.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : (sMa.containsMouse ? Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06) : "transparent")
        border.color: sTab.selected ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.30) : "transparent"
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Rectangle {
            visible: sTab.selected
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 18
            radius: 1.5
            color: Colors.primary
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            Text {
                text: sTab.icon
                font.pixelSize: 15
                color: sTab.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.65)
            }

            Text {
                text: sTab.label
                font.pixelSize: 13
                font.bold: sTab.selected
                color: sTab.selected ? Colors.primary : Colors.surfaceText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        MouseArea {
            id: sMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sTab.clicked()
        }
    }

    component SectionCard: Rectangle {
        id: cardRoot
        property string title: ""
        default property alias content: cardCol.data

        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + 32
        radius: 15
        color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.04)
        border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.08)
        border.width: 1

        ColumnLayout {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

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
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: swRow.label
                color: Colors.surfaceText
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                visible: swRow.subtitle !== ""
                text: swRow.subtitle
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.preferredWidth: 44
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

    component PlacementChip: Rectangle {
        id: pChip
        property string label: ""
        property string pos: "top"
        property bool selected: false
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 74
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
                Layout.preferredWidth: 44
                Layout.preferredHeight: 28
                radius: 6
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.06)
                border.color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.15)
                border.width: 1

                Rectangle {
                    radius: 2
                    color: pChip.selected ? Colors.primary : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.55)
                    x: pChip.pos === "right" ? parent.width - width - 4 : 4
                    y: pChip.pos === "bottom" ? parent.height - height - 4 : 4
                    width: (pChip.pos === "top" || pChip.pos === "bottom") ? parent.width - 8 : 6
                    height: (pChip.pos === "left" || pChip.pos === "right") ? parent.height - 8 : 5
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
        Layout.preferredHeight: 50
        radius: 12
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
        property bool danger: false
        signal clicked

        readonly property color pillColor: actPill.danger ? Colors.error : Colors.primary
        readonly property bool highlighted: actPill.accent || actPill.danger

        implicitWidth: pillRow.implicitWidth + 22
        Layout.preferredHeight: 32
        radius: 9
        color: actPill.highlighted ? Qt.rgba(actPill.pillColor.r, actPill.pillColor.g, actPill.pillColor.b, actMa.containsMouse ? 0.28 : 0.18) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, actMa.containsMouse ? 0.12 : 0.07)
        border.color: actPill.highlighted ? Qt.rgba(actPill.pillColor.r, actPill.pillColor.g, actPill.pillColor.b, 0.45) : Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12)
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
                color: actPill.highlighted ? actPill.pillColor : Colors.surfaceText
            }
            Text {
                text: actPill.label
                font.pixelSize: 12
                font.bold: true
                color: actPill.highlighted ? actPill.pillColor : Colors.surfaceText
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

    component SliderRow: ColumnLayout {
        id: slRow
        property string label: ""
        property string subtitle: ""
        property real value: 1.0
        property real minValue: 0.0
        property real maxValue: 1.0
        signal valueEdited(real newValue)

        readonly property real clampedNorm: Math.max(0, Math.min(1, (slRow.value - slRow.minValue) / Math.max(0.001, slRow.maxValue - slRow.minValue)))
        readonly property int percentValue: Math.round(slRow.value * 100)

        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: slRow.label
                    color: Colors.surfaceText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    visible: slRow.subtitle !== ""
                    text: slRow.subtitle
                    color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.52)
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                implicitWidth: pctText.implicitWidth + 16
                Layout.preferredHeight: 24
                radius: 7
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.14)
                border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.28)
                border.width: 1

                Text {
                    id: pctText
                    anchors.centerIn: parent
                    text: slRow.percentValue + "%"
                    color: Colors.primary
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        Item {
            id: slTrackArea
            Layout.fillWidth: true
            Layout.preferredHeight: 22

            function updateFromX(posX) {
                const usable = Math.max(1, slTrack.width);
                const t = Math.max(0, Math.min(1, posX / usable));
                const raw = slRow.minValue + t * (slRow.maxValue - slRow.minValue);
                const rounded = Math.round(raw * 100) / 100;
                slRow.valueEdited(rounded);
            }

            Rectangle {
                id: slTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: Qt.rgba(Colors.surfaceText.r, Colors.surfaceText.g, Colors.surfaceText.b, 0.12)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(6, slRow.clampedNorm * parent.width)
                    radius: 3
                    color: Colors.primary
                }
            }

            Rectangle {
                id: slThumb
                width: slMa.pressed ? 18 : 16
                height: slMa.pressed ? 18 : 16
                radius: width / 2
                anchors.verticalCenter: slTrack.verticalCenter
                x: Math.max(0, Math.min(slTrackArea.width - width, slRow.clampedNorm * (slTrackArea.width - width)))
                color: "#ffffff"
                border.color: Colors.primary
                border.width: 2
            }

            MouseArea {
                id: slMa
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => slTrackArea.updateFromX(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        slTrackArea.updateFromX(mouse.x);
                }
                onWheel: wheel => {
                    const step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                    const next = Math.max(slRow.minValue, Math.min(slRow.maxValue, Math.round((slRow.value + step) * 100) / 100));
                    slRow.valueEdited(next);
                }
            }
        }
    }

    component InfoLine: RowLayout {
        id: infoLine
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 12
        Text {
            text: infoLine.label
            color: Colors.surfaceText
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
            Layout.preferredWidth: 150
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
