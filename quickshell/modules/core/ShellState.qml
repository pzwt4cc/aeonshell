// ShellState.qml

pragma Singleton
import "../"
import QtQuick

QtObject {
    id: root

    property bool settingsWindowOpen: false
    property string settingsSection: "bar"
    property bool launcherOpen: false
    property bool suppressVolumeOSD: false

    property string cachedWeatherText: "Click to configure"
    property string cachedWeatherCity: "Moscow"
    property double cachedWeatherTimestamp: 0
    property string cachedInstallAge: ""
    property var cachedPkgs: null
}
