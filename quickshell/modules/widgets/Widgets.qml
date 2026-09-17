import Quickshell
import QtQuick
import "../"

Item {
    Variants {
        model: Quickshell.screens
        WidgetLayer {}
    }
}