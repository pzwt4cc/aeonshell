// NotificationService.qml

pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: service

    property bool dnd: false
    property var history: []
    property var active: []
    property int unreadCount: 0
    property int nextLocalId: 1

    readonly property string _chatAppsRegex: "discord|vesktop|telegram"

    function _setChatSoundsMuted(mute) {
        chatMuteProc.command = ["bash", "-c", `
pactl list sink-inputs | grep -E 'Sink Input #|application\\.name' | paste -d'|' - - |
while IFS='|' read -r idxline nameline; do
    idx=$(echo "$idxline" | grep -oE '[0-9]+')
    name=$(echo "$nameline" | sed -E 's/.*application\\.name = "(.*)"/\\1/')
    if echo "$name" | grep -qiE '` + service._chatAppsRegex + `'; then
        pactl set-sink-input-mute "$idx" ` + (mute ? "1" : "0") + `
    fi
done
`];
        chatMuteProc.running = true;
    }

    Process { id: chatMuteProc }

    onDndChanged: service._setChatSoundsMuted(service.dnd)

    readonly property var appAliases: ({
        "discord": { classMatch: ["discord", "vesktop"], launch: "vesktop" },
        "vesktop": { classMatch: ["discord", "vesktop"], launch: "vesktop" },
        "telegram": { classMatch: ["telegram", "org.telegram.desktop"], launch: "telegram-desktop" },
        "telegramdesktop": { classMatch: ["telegram", "org.telegram.desktop"], launch: "telegram-desktop" },
        "org.telegram.desktop": { classMatch: ["telegram", "org.telegram.desktop"], launch: "telegram-desktop" }
    })

    property var pendingRaiseEntry: null

    function focusOrLaunchSource(entry) {
        if (!entry) return;
        service.pendingRaiseEntry = entry;
        clientsProbe.running = true;
    }

    Process {
        id: clientsProbe
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const entry = service.pendingRaiseEntry;
                service.pendingRaiseEntry = null;
                if (!entry) return;

                let clients = [];
                try { clients = JSON.parse(this.text); } catch (e) { clients = []; }

                const rawName = (entry.appName || "").toLowerCase();
                const rawDesktop = (entry.desktopEntry || "").toLowerCase();
                const alias = service.appAliases[rawName] || service.appAliases[rawDesktop] || null;

                let needles = [rawName, rawDesktop];
                if (alias) needles = needles.concat(alias.classMatch);
                needles = needles.filter(function (s) { return s && s.length > 0; });

                function matches(str) {
                    if (!str) return false;
                    const s = str.toLowerCase();
                    for (const n of needles) {
                        if (s.indexOf(n) !== -1 || n.indexOf(s) !== -1) return true;
                    }
                    return false;
                }

                let found = null;
                for (const c of clients) {
                    if (matches(c.class) || matches(c.initialClass) || matches(c.title)) {
                        found = c;
                        break;
                    }
                }

                if (found && found.address) {
                    focusProc.command = ["hyprctl", "dispatch", "focuswindow", "address:" + found.address];
                    focusProc.running = true;
                } else {
                    const launchName = alias ? alias.launch : (rawDesktop || rawName);
                    if (!launchName) return;
                    launchProc.fallbackCmd = [launchName];
                    launchProc.command = ["gtk-launch", launchName];
                    launchProc.running = true;
                }
            }
        }
    }

    Process { id: focusProc }

    Process {
        id: launchProc
        property var fallbackCmd: []
        onExited: (exitCode) => {
            if (exitCode !== 0 && launchProc.fallbackCmd.length > 0) {
                rawExecProc.command = launchProc.fallbackCmd;
                rawExecProc.running = true;
            }
        }
    }

    Process { id: rawExecProc }

    function clearAll() {
        history = [];
        unreadCount = 0;
    }

    function markAllRead() {
        unreadCount = 0;
    }

    function dismissAt(idx) {
        let arr = history.slice();
        arr.splice(idx, 1);
        history = arr;
    }

    function dismissActive(localId) {
        active = active.filter(function (n) { return n.localId !== localId; });
    }

    function dismissByLocalId(localId) {
        active = active.filter(function (n) { return n.localId !== localId; });
        history = history.filter(function (n) { return n.localId !== localId; });
    }

    function activateSource(entry) {
        if (!entry || !entry.sourceNotif) return false;
        const actions = entry.sourceNotif.actions;
        if (!actions || actions.length === 0) return false;

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

        onNotification: (notification) => {
            console.log("=== Notification received! ===");
            console.log("From: " + notification.appName);
            console.log("Title: " + notification.summary);

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
                appName: notification.appName || notification.desktopEntry || "Application",
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

            notification.closed.connect(function(reason) {
                if (reason === 2 || reason === 3) {
                    service.dismissByLocalId(entry.localId);
                }
            });

            if (!service.dnd) {
                let harr = service.history.slice();
                harr.unshift(entry);
                if (harr.length > 50) harr.pop();
                service.history = harr;
                service.unreadCount += 1;

                let aarr = service.active.slice();
                aarr.push(entry);
                service.active = aarr;
                console.log("Successfully added! Active count: " + service.active.length);
            } else {
                console.log("Notification ignored (DND mode enabled).");
            }
        }
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (service.active.some(function (n) { return n.expiresAt <= now; })) {
                service.active = service.active.filter(function (n) { return n.expiresAt > now; });
            }
        }
    }
}