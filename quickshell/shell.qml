//@ pragma UseQApplication
import Quickshell
import QtQuick
import "./modules"

ShellRoot {
    FontLoader {
        id: materialSymbols
        source: "./assets/MaterialSymbolsRounded.ttf"
    }

    Bar {}
    Dock {}
    NotificationToasts {}
    Launcher {}
    Screenshot {}
    Clipboard {}
    SettingsWindow {}
    VolumeOSD {}
}