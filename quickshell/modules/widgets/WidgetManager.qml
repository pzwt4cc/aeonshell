pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var widgets: []
    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/widgets.json"

    FileView {
        id: file
        path: root.configPath
        onLoaded: {
            try {
                let parsed = JSON.parse(text())
                root.widgets = Array.isArray(parsed) ? parsed : []
            } catch (e) {
                root.widgets = []
            }
        }
        onLoadFailed: (error) => { root.widgets = [] }
    }

    function save() {
        file.setText(JSON.stringify(root.widgets))
    }

    function addWidget(type, screenName, x, y) {
        let w = widgets.slice()
        w.push({ id: Date.now(), type: type, screen: screenName, x: x, y: y, locked: false })
        widgets = w
        save()
    }

    function removeWidget(id) {
        widgets = widgets.filter(w => w.id !== id)
        save()
    }

    // вызывать только по release драга, не по каждому move
    function commitPosition(id, x, y) {
        let w = widgets.slice()
        let idx = w.findIndex(item => item.id === id)
        if (idx >= 0) { w[idx].x = x; w[idx].y = y; widgets = w; save() }
    }

    function toggleLock(id) {
        let w = widgets.slice()
        let idx = w.findIndex(item => item.id === id)
        if (idx >= 0) { w[idx].locked = !w[idx].locked; widgets = w; save() }
    }

    function changeType(id, newType) {
        let w = widgets.slice()
        let idx = w.findIndex(item => item.id === id)
        if (idx >= 0) { w[idx].type = newType; widgets = w; save() }
    }
}