// NotificationService.qml

pragma Singleton
import "../"
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Hyprland

Item {
    id: service

    property bool dnd: false
    property var history: []
    property var active: []
    property int unreadCount: 0
    property int nextLocalId: 1

    readonly property var _chatKeywords: ["discord", "vesktop", "telegram"]

    readonly property var chatStreamNodes: {
        const list = [...Pipewire.nodes.values];
        return list.filter(function (n) {
            if (!n || !n.isStream || !n.audio)
                return false;
            const props = n.properties || ({});
            const appName = (props["application.name"] || props["application.process.binary"] || n.name || "").toLowerCase();
            for (let i = 0; i < service._chatKeywords.length; i++) {
                if (appName.indexOf(service._chatKeywords[i]) !== -1)
                    return true;
            }
            return false;
        });
    }

    PwObjectTracker {
        objects: service.chatStreamNodes
    }

    function _syncChatMute() {
        const nodes = service.chatStreamNodes;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && n.audio)
                n.audio.muted = service.dnd;
        }
    }

    onDndChanged: service._syncChatMute()
    onChatStreamNodesChanged: if (service.dnd)
        service._syncChatMute()

    readonly property var appAliases: ({
            "discord": {
                classMatch: ["discord", "vesktop"],
                launch: "vesktop"
            },
            "vesktop": {
                classMatch: ["discord", "vesktop"],
                launch: "vesktop"
            },
            "telegram": {
                classMatch: ["telegram", "org.telegram.desktop"],
                launch: "telegram-desktop"
            },
            "telegramdesktop": {
                classMatch: ["telegram", "org.telegram.desktop"],
                launch: "telegram-desktop"
            },
            "org.telegram.desktop": {
                classMatch: ["telegram", "org.telegram.desktop"],
                launch: "telegram-desktop"
            }
        })

    function focusOrLaunchSource(entry) {
        if (!entry)
            return;

        const rawName = (entry.appName || "").toLowerCase();
        const rawDesktop = (entry.desktopEntry || "").toLowerCase();
        const alias = service.appAliases[rawName] || service.appAliases[rawDesktop] || null;

        let needles = [rawName, rawDesktop];
        if (alias)
            needles = needles.concat(alias.classMatch);
        needles = needles.filter(function (s) {
            return s && s.length > 0;
        });

        function matches(str) {
            if (!str)
                return false;
            const s = str.toLowerCase();
            for (const n of needles) {
                if (s.indexOf(n) !== -1 || n.indexOf(s) !== -1)
                    return true;
            }
            return false;
        }

        let found = null;
        const toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            const ipc = t.lastIpcObject || ({});
            if (matches(ipc.class) || matches(ipc.initialClass) || matches(t.title)) {
                found = t;
                break;
            }
        }

        if (found) {
            const addr = (found.lastIpcObject && found.lastIpcObject.address) ? found.lastIpcObject.address : ("0x" + found.address);
            if (Hyprland.usingLua) {
                Hyprland.dispatch("hl.dsp.focus({ window = hl.get_windows({ address = \"" + addr + "\" })[1] })");
            } else {
                Hyprland.dispatch("focuswindow address:" + addr);
            }
            return;
        }

        const launchName = alias ? alias.launch : (rawDesktop || rawName);
        if (!launchName)
            return;

        const desktop = DesktopEntries.byId(launchName) || DesktopEntries.byId(rawDesktop);
        if (desktop) {
            desktop.execute();
        } else {
            Quickshell.execDetached([launchName]);
        }
    }

    function clearAll() {
        history = [];
        unreadCount = 0;
    }

    function markAllRead() {
        unreadCount = 0;
    }

    function dismissAt(idx) {
        if (idx < 0 || idx >= history.length)
            return;
        const arr = history.slice();
        arr.splice(idx, 1);
        history = arr;
    }

    function dismissByLocalId(localId) {
        active = active.filter(function (n) {
            return n.localId !== localId;
        });
        history = history.filter(function (n) {
            return n.localId !== localId;
        });
    }

    function activateSource(entry) {
        if (!entry || !entry.sourceNotif)
            return false;
        const actions = entry.sourceNotif.actions;
        if (!actions || actions.length === 0)
            return false;

        for (let i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") {
                actions[i].invoke();
                return true;
            }
        }
        actions[0].invoke();
        return true;
    }

    function openSource(entry) {
        service.activateSource(entry);
        service.focusOrLaunchSource(entry);
    }

    NotificationServer {
        id: notifServer
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: notification => {
            notification.tracked = true;
            let durationMs = 5000;
            if (notification.expireTimeout && notification.expireTimeout > 0) {
                durationMs = notification.expireTimeout * 1000;
            } else if (notification.urgency === NotificationUrgency.Critical) {
                durationMs = 10000;
            } else if (notification.urgency === NotificationUrgency.Low) {
                durationMs = 4000;
            }

            const entry = {
                localId: service.nextLocalId++,
                sourceNotif: notification,
                appName: notification.appName || notification.desktopEntry || "",
                desktopEntry: notification.desktopEntry || "",
                summary: notification.summary || "",
                body: notification.body || "",
                image: notification.image || "",
                appIcon: notification.appIcon || "",
                time: Qt.formatDateTime(new Date(), "hh:mm"),
                urgency: notification.urgency,
                durationMs: durationMs,
                expiresAt: Date.now() + durationMs
            };

            notification.closed.connect(function (reason) {
                if (reason === 2 || reason === 3) {
                    service.dismissByLocalId(entry.localId);
                }
            });

            const harr = service.history.slice();
            harr.unshift(entry);
            if (harr.length > 50)
                harr.pop();
            service.history = harr;

            if (!service.dnd) {
                service.unreadCount += 1;
                const aarr = service.active.slice();
                aarr.push(entry);
                service.active = aarr;
            }
        }
    }

    Timer {
        interval: 400
        running: service.active.length > 0
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (service.active.some(function (n) {
                return n.expiresAt <= now;
            })) {
                service.active = service.active.filter(function (n) {
                    return n.expiresAt > now;
                });
            }
        }
    }
}
