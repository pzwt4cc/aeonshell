// Colors.qml

pragma Singleton
import "../"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    Component.onCompleted: {
        Qt.application.organization = "aeonshell";
        Qt.application.name = "aeonshell";
        dirInitProc.running = true;
    }

    property color background: "#13140d"
    property color surface: "#13140d"
    property color surfaceText: "#e4e3d7"
    property color primary: "#bece7f"
    property color secondary: "#c4caa8"
    property color error: "#ffb4ab"
    property color outline: Qt.lighter(surface, 1.8)

    property bool generatingTheme: false
    property string themeSource: "default"
    property string _pendingImagePath: ""
    property var _pendingCallback: null

    readonly property string cacheJsonPath: AppSettings.colorsCachePath

    function _toHex(c) {
        const col = Qt.color(c);
        const r = Math.round(col.r * 255).toString(16).padStart(2, "0");
        const g = Math.round(col.g * 255).toString(16).padStart(2, "0");
        const b = Math.round(col.b * 255).toString(16).padStart(2, "0");
        return "#" + r + g + b;
    }

    function updateColors(jsonStr) {
        try {
            const data = JSON.parse(jsonStr);

            if (data.background)
                root.background = data.background;
            if (data.surface || data.background)
                root.surface = data.surface || data.background;
            if (data.surfaceText)
                root.surfaceText = data.surfaceText;
            if (data.primary)
                root.primary = data.primary;
            if (data.secondary)
                root.secondary = data.secondary;
            if (data.error)
                root.error = data.error;
            if (data.outline)
                root.outline = data.outline;

            if (data.source)
                root.themeSource = data.source;
            else if (root.themeSource === "default")
                root.themeSource = "cache";
        } catch (e) {
            console.log("[Colors] Theme parsing error:", e);
        }
    }

    function _applyPalette(pal, sourceTag) {
        root.background = pal.background;
        root.surface = pal.surface;
        root.surfaceText = pal.surfaceText;
        root.primary = pal.primary;
        root.secondary = pal.secondary;
        root.error = pal.error;
        root.outline = pal.outline;

        root.themeSource = sourceTag || "cache";
        const jsonPayload = {
            source: root.themeSource,
            background: pal.background,
            surface: pal.surface,
            surfaceText: pal.surfaceText,
            primary: pal.primary,
            secondary: pal.secondary,
            error: pal.error,
            outline: pal.outline
        };
        colorsOutFile.setText(JSON.stringify(jsonPayload, null, 2) + "\n");
    }

    function _paletteFromMatugen(rawJson) {
        const data = JSON.parse(rawJson);
        const c = data.colors || {};
        const pick = (obj, fallback) => (obj && obj.dark && obj.dark.color) ? obj.dark.color : fallback;

        const background = pick(c.background, "#13140d");
        const surface = pick(c.surface, background);
        const surfaceText = pick(c.on_surface, "#e4e3d7");
        const primary = pick(c.primary, "#bece7f");
        const secondary = pick(c.secondary, "#c4caa8");
        const error = pick(c.error, "#ffb4ab");
        const outline = pick(c.outline, "#8f9282");

        return {
            background: background,
            surface: surface,
            surfaceText: surfaceText,
            primary: primary,
            secondary: secondary,
            error: error,
            outline: outline
        };
    }

    function _paletteFromQuantizer(cols) {
        if (!cols || cols.length === 0)
            return null;

        let bestBg = cols[0];
        let bestAccent = cols[0];
        let secondAccent = cols[Math.min(1, cols.length - 1)];
        let minLum = 2.0;
        let maxScore = -1.0;

        for (let i = 0; i < cols.length; i++) {
            const col = Qt.color(cols[i]);
            const lum = 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b;
            const sat = col.hslSaturation;
            if (lum < minLum) {
                minLum = lum;
                bestBg = col;
            }
            const score = sat * 1.4 + (1.0 - Math.abs(lum - 0.55));
            if (score > maxScore) {
                maxScore = score;
                secondAccent = bestAccent;
                bestAccent = col;
            }
        }

        const bgCol = Qt.hsla(bestBg.hslHue, Math.min(0.28, bestBg.hslSaturation), 0.08, 1.0);
        const priCol = Qt.hsla(bestAccent.hslHue, Math.max(0.45, Math.min(0.85, bestAccent.hslSaturation)), 0.72, 1.0);
        let secHue = secondAccent.hslHue;
        if (Math.abs(secHue - priCol.hslHue) < 0.06)
            secHue = (priCol.hslHue + 0.12) % 1.0;
        const secCol = Qt.hsla(secHue, Math.max(0.32, Math.min(0.75, secondAccent.hslSaturation)), 0.76, 1.0);
        const fgCol = Qt.hsla(priCol.hslHue, 0.12, 0.90, 1.0);
        const outCol = Qt.hsla(bgCol.hslHue, 0.14, 0.56, 1.0);

        const background = root._toHex(bgCol);
        return {
            background: background,
            surface: background,
            surfaceText: root._toHex(fgCol),
            primary: root._toHex(priCol),
            secondary: root._toHex(secCol),
            error: "#ffb4ab",
            outline: root._toHex(outCol)
        };
    }

    function _finishThemeGeneration(ok) {
        root.generatingTheme = false;
        const cb = root._pendingCallback;
        root._pendingCallback = null;
        root._pendingImagePath = "";
        if (cb)
            cb(ok);
    }

    function applyThemeFromImage(imagePath, onDone) {
        if (!imagePath) {
            if (onDone)
                onDone(false);
            return;
        }
        root._pendingImagePath = imagePath;
        root._pendingCallback = onDone || null;
        root.generatingTheme = true;

        if (matugenProc.running)
            matugenProc.running = false;
        matugenProc.command = ["matugen", "image", imagePath, "--source-color-index", "0", "-j", "hex"];
        matugenProc.running = true;
    }

    Process {
        id: dirInitProc
        command: ["mkdir", "-p", AppSettings.cacheDir]
    }

    Process {
        id: matugenProc
        property string outputBuf: ""
        stdout: StdioCollector {
            onStreamFinished: matugenProc.outputBuf = this.text
        }
        onExited: exitCode => {
            if (exitCode === 0 && matugenProc.outputBuf.trim() !== "") {
                try {
                    const pal = root._paletteFromMatugen(matugenProc.outputBuf);
                    root._applyPalette(pal, "matugen");
                    root._finishThemeGeneration(true);
                    return;
                } catch (e) {
                    console.log("[Colors] matugen parse failed, falling back to ColorQuantizer:", e);
                }
            }
            if (root._pendingImagePath) {
                quantizer.source = "";
                quantizer.source = "file://" + root._pendingImagePath;
            } else {
                root._finishThemeGeneration(false);
            }
        }
    }

    ColorQuantizer {
        id: quantizer
        depth: 3
        rescaleSize: 64
        onColorsChanged: {
            if (!root.generatingTheme || !root._pendingImagePath)
                return;
            const pal = root._paletteFromQuantizer(quantizer.colors);
            if (pal) {
                root._applyPalette(pal, "quantizer");
                root._finishThemeGeneration(true);
            } else {
                root._finishThemeGeneration(false);
            }
        }
    }

    FileView {
        id: colorsFile
        path: root.cacheJsonPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            const text = colorsFile.text();
            if (text && text.trim() !== "")
                root.updateColors(text);
        }
        onFileChanged: reload()
    }

    FileView {
        id: colorsOutFile
        path: root.cacheJsonPath
        preload: false
        printErrors: false
    }
}
