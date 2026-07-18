// MprisService.qml

pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

Item {
    id: service

    readonly property var players: Mpris.players

    property string preferredDbusName: ""

    readonly property var currentPlayer: {
        const list = service.players.values
        if (service.preferredDbusName) {
            for (let i = 0; i < list.length; i++) {
                if (list[i].dbusName === service.preferredDbusName) return list[i]
            }
        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying) return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    readonly property bool active: service.currentPlayer !== null
    readonly property bool isPlaying: service.active && service.currentPlayer.isPlaying

    readonly property string trackTitle: service.active ? (service.currentPlayer.trackTitle || "") : ""
    readonly property string trackArtist: service.active ? (service.currentPlayer.trackArtist || "") : ""
    readonly property string playerName: service.active ? (service.currentPlayer.desktopEntry || service.currentPlayer.identity || "") : ""

    readonly property real volumeLevel: (service.active && service.currentPlayer.volumeSupported) ? service.currentPlayer.volume : 0
    readonly property real length: service.active ? service.currentPlayer.length : 0
    readonly property real trackProgress: (service.active && service.length > 0) ? Math.min(1, service.currentPlayer.position / service.length) : 0

    readonly property var playerList: service.players.values.map(function(p) { return p.dbusName })

    function identityFor(dbusName) {
        const list = service.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].dbusName === dbusName) return list[i].desktopEntry || list[i].identity || ""
        }
        return ""
    }

    function formatTime(seconds) {
        let total = Math.floor(seconds || 0)
        if (isNaN(total) || total < 0) return "00:00"
        let m = Math.floor(total / 60)
        let s = total % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
    readonly property string positionStr: service.active ? service.formatTime(service.currentPlayer.position) : "00:00"
    readonly property string durationStr: service.active ? service.formatTime(service.length) : "00:00"

    function selectPlayer(dbusName) { service.preferredDbusName = dbusName }

    function playPause() { if (service.active && service.currentPlayer.canTogglePlaying) service.currentPlayer.togglePlaying() }
    function next() { if (service.active && service.currentPlayer.canGoNext) service.currentPlayer.next() }
    function previous() { if (service.active && service.currentPlayer.canGoPrevious) service.currentPlayer.previous() }

    function seekToFraction(pct) {
        if (service.active && service.currentPlayer.canSeek && service.currentPlayer.positionSupported && service.length > 0) {
            service.currentPlayer.position = service.length * pct
        }
    }

    property real _savedVolume: 1.0
    function setVolume(v) {
        if (service.active && service.currentPlayer.volumeSupported) service.currentPlayer.volume = Math.max(0, Math.min(1, v))
    }
    function toggleMute() {
        if (!service.active || !service.currentPlayer.volumeSupported) return
        if (service.currentPlayer.volume > 0) {
            service._savedVolume = service.currentPlayer.volume
            service.currentPlayer.volume = 0
        } else {
            service.currentPlayer.volume = service._savedVolume > 0 ? service._savedVolume : 0.5
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: service.isPlaying
        onTriggered: if (service.currentPlayer) service.currentPlayer.positionChanged()
    }
}
