// ShellState.qml

pragma Singleton
import "../"
import QtQuick

QtObject {
    id: root

    property bool settingsWindowOpen: false
    property string settingsSection: "bar"
}
