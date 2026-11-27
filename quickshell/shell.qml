//@ pragma UseQApplication
import Quickshell
import QtQuick
import "./modules"

ShellRoot {
    readonly property bool launcherOnly: Quickshell.env("AEONSHELL_LAUNCHER_ONLY") === "1"

    // Keep fullscreen/watchdog active even while Launcher is lazy-unloaded
    readonly property var _mpvWatcherKeepAlive: launcherOnly ? null : MpvFullscreenWatcher

    LazyLoader {
        id: barLoader
        active: !launcherOnly
        Bar {}
    }

    LazyLoader {
        id: notificationToastsLoader
        active: !launcherOnly && NotificationService.active.length > 0
        NotificationToasts {}
    }

    LazyLoader {
        id: launcherLoader
        active: true
        Launcher {
            open: launcherOnly
        }
    }

    LazyLoader {
        id: screenshotLoader
        active: !launcherOnly
        Screenshot {}
    }

    LazyLoader {
        id: clipboardLoader
        active: !launcherOnly
        Clipboard {}
    }

    LazyLoader {
        id: settingsWindowLoader
        active: !launcherOnly
        SettingsWindow {}
    }

    LazyLoader {
        id: volumeOsdLoader
        active: !launcherOnly
        VolumeOSD {}
    }
}
