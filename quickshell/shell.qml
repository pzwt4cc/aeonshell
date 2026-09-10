//@ pragma UseQApplication
import Quickshell
import QtQuick
import "./modules"

ShellRoot {
    FontLoader {
        id: materialSymbols
        source: "./assets/MaterialSymbolsRounded.ttf"
    }

    LazyLoader {
        id: barLoader
        active: true
        onItemChanged: if (item) console.log("[shell] Bar: ok")
        Bar {}
    }

    LazyLoader {
        id: notificationToastsLoader
        active: true
        onItemChanged: if (item) console.log("[shell] NotificationToasts: ok")
        NotificationToasts {}
    }

    LazyLoader {
        id: launcherLoader
        active: true
        onItemChanged: if (item) console.log("[shell] Launcher: ok")
        Launcher {}
    }

    LazyLoader {
        id: screenshotLoader
        active: true
        onItemChanged: if (item) console.log("[shell] Screenshot: ok")
        Screenshot {}
    }

    LazyLoader {
        id: clipboardLoader
        active: true
        onItemChanged: if (item) console.log("[shell] Clipboard: ok")
        Clipboard {}
    }

    LazyLoader {
        id: settingsWindowLoader
        active: true
        onItemChanged: if (item) console.log("[shell] SettingsWindow: ok")
        SettingsWindow {}
    }

    LazyLoader {
        id: volumeOsdLoader
        active: true
        onItemChanged: if (item) console.log("[shell] VolumeOSD: ok")
        VolumeOSD {}
    }
}
