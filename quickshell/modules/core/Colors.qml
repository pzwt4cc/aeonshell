// Colors.qml

pragma Singleton
import "../"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    Component.onCompleted: {
        Qt.application.organization = "quickshell-config";
        Qt.application.name = "quickshell";
        dirInitProc.running = true;
    }

    property color background: "#13140d"
    property color surface: "#13140d"
    property color surfaceText: "#e4e3d7"
    property color primary: "#bece7f"
    property color secondary: "#c4caa8"
    property color error: "#ffb4ab"
    property color outline: Qt.lighter(surface, 1.8)
    property color barBackdrop: Qt.rgba(0.075, 0.078, 0.05, 0.55)

    property bool generatingTheme: false
    property string themeSource: "default"
    property string _pendingImagePath: ""
    property var _pendingCallback: null
    property string _lastCavaBase: ""

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string cacheJsonPath: root.homeDir + "/.cache/aeonshell/colors.json"
    readonly property string legacyWalJsonPath: root.homeDir + "/.cache/wal/colors.json"
    readonly property string kittyColorsPath: root.homeDir + "/.cache/wal/colors-kitty.conf"
    readonly property string cavaConfigPath: root.homeDir + "/.config/cava/config"

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
            const bgVal = data.background || (data.special && data.special.background);
            const surfVal = data.surface || bgVal;
            const fgVal = data.surfaceText || (data.special && data.special.foreground);
            const priVal = data.primary || (data.colors && data.colors.color1);
            const secVal = data.secondary || (data.colors && data.colors.color2);
            const errVal = data.error || (data.colors && data.colors.color3);
            const outVal = data.outline;

            if (bgVal)
                root.background = bgVal;
            if (surfVal)
                root.surface = surfVal;
            if (fgVal)
                root.surfaceText = fgVal;
            if (priVal)
                root.primary = priVal;
            if (secVal)
                root.secondary = secVal;
            if (errVal)
                root.error = errVal;
            if (outVal)
                root.outline = outVal;

            if (data.source)
                root.themeSource = data.source;
            else if (root.themeSource === "default")
                root.themeSource = "cache";

            const bg = Qt.color(root.background);
            root.barBackdrop = Qt.rgba(bg.r, bg.g, bg.b, 0.55);
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
        const bgCol = Qt.color(pal.background);
        root.barBackdrop = Qt.rgba(bgCol.r, bgCol.g, bgCol.b, 0.55);

        root.themeSource = sourceTag || "cache";
        const jsonPayload = {
            source: root.themeSource,
            background: pal.background,
            surface: pal.surface,
            surfaceText: pal.surfaceText,
            primary: pal.primary,
            secondary: pal.secondary,
            error: pal.error,
            outline: pal.outline,
            special: {
                background: pal.background,
                foreground: pal.surfaceText,
                cursor: pal.primary
            },
            colors: pal.term16
        };
        colorsOutFile.setText(JSON.stringify(jsonPayload, null, 2) + "\n");

        const p16 = pal.term16;
        let kitty = "background " + pal.background + "\n" + "foreground " + pal.surfaceText + "\n" + "cursor " + pal.primary + "\n" + "selection_background " + pal.primary + "\n" + "selection_foreground " + pal.background + "\n";
        for (let i = 0; i < 16; i++) {
            kitty += "color" + i + " " + p16["color" + i] + "\n";
        }
        kittyOutFile.setText(kitty);

        const baseConf = (root._lastCavaBase || "[general]\nbar_width = 2\nbar_spacing = 1\novershoot = 100\nmax_height = 100\n").replace(/\n*\[color\][\s\S]*$/m, "").trimEnd();
        const cavaText = baseConf + "\n\n[color]\ngradient = 1\n" + "gradient_color_1 = '" + pal.primary + "'\n" + "gradient_color_2 = '" + pal.secondary + "'\n" + "background = 'default'\n";
        cavaOutFile.setText(cavaText);
        Quickshell.execDetached(["pkill", "-USR2", "cava"]);
    }

    function _paletteFromMatugen(rawJson) {
        const data = JSON.parse(rawJson);
        const c = data.colors || {};
        const b = data.base16 || {};
        const pick = (obj, fallback) => (obj && obj.dark && obj.dark.color) ? obj.dark.color : fallback;

        const background = pick(c.background, "#13140d");
        const surface = pick(c.surface, background);
        const surfaceText = pick(c.on_surface, "#e4e3d7");
        const primary = pick(c.primary, "#bece7f");
        const secondary = pick(c.secondary, "#c4caa8");
        const error = pick(c.error, "#ffb4ab");
        const outline = pick(c.outline, "#8f9282");

        const term16 = {
            color0: pick(b.base00, background),
            color1: pick(b.base08, error),
            color2: pick(b.base0b, primary),
            color3: pick(b.base0a, secondary),
            color4: pick(b.base0d, primary),
            color5: pick(b.base0e, secondary),
            color6: pick(b.base0c, secondary),
            color7: pick(b.base05, surfaceText),
            color8: pick(b.base03, outline),
            color9: pick(b.base08, error),
            color10: pick(b.base0b, primary),
            color11: pick(b.base0a, secondary),
            color12: pick(b.base0d, primary),
            color13: pick(b.base0e, secondary),
            color14: pick(b.base0c, secondary),
            color15: pick(b.base07, surfaceText)
        };

        return {
            background: background,
            surface: surface,
            surfaceText: surfaceText,
            primary: primary,
            secondary: secondary,
            error: error,
            outline: outline,
            term16: term16
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
        const primary = root._toHex(priCol);
        const secondary = root._toHex(secCol);
        const surfaceText = root._toHex(fgCol);
        const outline = root._toHex(outCol);
        const error = "#ffb4ab";

        return {
            background: background,
            surface: background,
            surfaceText: surfaceText,
            primary: primary,
            secondary: secondary,
            error: error,
            outline: outline,
            term16: {
                color0: background,
                color1: "#f38ba8",
                color2: primary,
                color3: secondary,
                color4: root._toHex(Qt.hsla((priCol.hslHue + 0.55) % 1.0, 0.55, 0.70, 1.0)),
                color5: root._toHex(Qt.hsla((priCol.hslHue + 0.75) % 1.0, 0.55, 0.72, 1.0)),
                color6: root._toHex(Qt.hsla((priCol.hslHue + 0.40) % 1.0, 0.55, 0.72, 1.0)),
                color7: surfaceText,
                color8: outline,
                color9: "#f38ba8",
                color10: primary,
                color11: secondary,
                color12: root._toHex(Qt.hsla((priCol.hslHue + 0.55) % 1.0, 0.60, 0.76, 1.0)),
                color13: root._toHex(Qt.hsla((priCol.hslHue + 0.75) % 1.0, 0.60, 0.78, 1.0)),
                color14: root._toHex(Qt.hsla((priCol.hslHue + 0.40) % 1.0, 0.60, 0.78, 1.0)),
                color15: "#ffffff"
            }
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
        command: ["mkdir", "-p", root.homeDir + "/.cache/aeonshell", root.homeDir + "/.cache/wal", root.homeDir + "/.config/cava"]
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
        onLoadFailed: legacyColorsFile.reload()
        onFileChanged: reload()
    }

    FileView {
        id: legacyColorsFile
        path: root.legacyWalJsonPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            const text = legacyColorsFile.text();
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

    FileView {
        id: kittyOutFile
        path: root.kittyColorsPath
        preload: false
        printErrors: false
    }

    FileView {
        id: cavaOutFile
        path: root.cavaConfigPath
        printErrors: false
        onLoaded: root._lastCavaBase = cavaOutFile.text()
    }
}
