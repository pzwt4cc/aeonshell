//@ pragma UseQApplication
import Quickshell
import QtQuick
import "./modules"

pragma ComponentBehavior: Bound

ShellRoot {
    id: shellRoot
    readonly property bool launcherOnly: Quickshell.env("AEONSHELL_LAUNCHER_ONLY") === "1"

    // Keep fullscreen/watchdog active even while Launcher is lazy-unloaded
    readonly property var _mpvWatcherKeepAlive: launcherOnly ? null : MpvFullscreenWatcher

    LazyLoader {
        id: barLoader
        active: !shellRoot.launcherOnly
        Bar {}
    }

    LazyLoader {
        id: notificationToastsLoader
        active: !shellRoot.launcherOnly && NotificationService.active.length > 0
        NotificationToasts {}
    }

    LazyLoader {
        id: launcherLoader
        active: true
        Launcher {
            open: shellRoot.launcherOnly
        }
    }

    LazyLoader {
        id: screenshotLoader
        active: !shellRoot.launcherOnly
        Screenshot {}
    }

    LazyLoader {
        id: clipboardLoader
        active: !shellRoot.launcherOnly
        Clipboard {}
    }

    LazyLoader {
        id: settingsWindowLoader
        active: !shellRoot.launcherOnly
        SettingsWindow {}
    }

    LazyLoader {
        id: volumeOsdLoader
        active: !shellRoot.launcherOnly
        VolumeOSD {}
    }
}
