// Colors.qml

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    Component.onCompleted: {
        Qt.application.organization = "quickshell-config";
        Qt.application.name = "quickshell";
    }

    property color background: "#13140d"
    property color surface: "#13140d"
    property color surfaceText: "#e4e3d7"
    property color primary: "#bece7f"
    property color secondary: "#c4caa8"
    property color error: "#ffb4ab"
    property color barBackdrop: Qt.rgba(0.075, 0.078, 0.05, 0.55)

    property color surfaceContainer: Qt.lighter(surface, 1.15)
    property color surfaceContainerHigh: Qt.lighter(surface, 1.3)
    property color surfaceContainerHighest: Qt.lighter(surface, 1.45)
    property color surfaceVariantText: Qt.darker(surfaceText, 1.15)

    property color primaryText: Qt.darker(primary, 1.5)
    property color primaryContainer: Qt.darker(primary, 1.3)

    property color secondaryContainer: Qt.darker(secondary, 1.3)
    property color errorContainer: Qt.darker(error, 1.4)

    property color outline: Qt.lighter(surface, 1.8)
    property color outlineVariant: Qt.lighter(surface, 1.4)

    function updateColors(jsonStr) {
        try {
            const data = JSON.parse(jsonStr);
            root.background = data.special.background;
            root.surface = data.special.background;
            root.surfaceText = data.special.foreground;
            root.primary = data.colors.color1;
            root.secondary = data.colors.color2;
            root.error = data.colors.color3;
            let bg = Qt.color(data.special.background);
            root.barBackdrop = Qt.rgba(bg.r, bg.g, bg.b, 0.55);
        } catch (e) {
            console.log("Theme parsing error: " + e);
        }
    }

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true

        onLoaded: {
            const text = colorsFile.text();
            if (text && text.trim() !== "") {
                root.updateColors(text);
            }
        }

        onFileChanged: reload()
    }
}
