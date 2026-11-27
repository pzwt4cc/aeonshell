// ShellState.qml

pragma Singleton
import "../"
import QtQuick

QtObject {
    id: root

    property bool settingsWindowOpen: false
    property string settingsSection: "appearance"
    property bool openWallpaperRequested: false
    property bool launcherOpen: false
    property bool suppressVolumeOSD: false

    property string cachedWeatherStatus: "unconfigured" // "ok" | "offline" | "not_found" | "unconfigured"
    property int cachedWeatherCode: -1
    property int cachedWeatherTemp: 0
    property string cachedWeatherCity: "Moscow"
    property double cachedWeatherTimestamp: 0
    property string cachedInstallDate: ""
    property var cachedPkgs: null
}
