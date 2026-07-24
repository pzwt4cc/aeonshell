#!/usr/bin/env bash
# Restores the last wallpaper (static image OR video) per monitor after
# login/reboot. Static images are usually already restored automatically by
# awww-daemon itself, but video wallpapers (mpvpaper) have no restore
# mechanism of their own, so this script is what brings those back.
#
# State is read from ~/.cache/aeonshell/wallpaper-state/<monitor>, written
# by Launcher.qml's applyWallpaper(). Each file contains one line:
#   video|/absolute/path/to/file.mp4
# or
#   image|/absolute/path/to/file.png

HOME="${HOME:-/home/$(id -un)}"
STATE_DIR="$HOME/.cache/aeonshell/wallpaper-state"

[ -d "$STATE_DIR" ] || exit 0

# Give Hyprland/monitors a moment to be fully up before we query them.
sleep 1

for state_file in "$STATE_DIR"/*; do
    [ -f "$state_file" ] || continue
    mon=$(basename "$state_file")
    line=$(cat "$state_file" 2>/dev/null)
    [ -z "$line" ] && continue

    kind="${line%%|*}"
    file="${line#*|}"
    [ -f "$file" ] || continue

    # Skip monitors that aren't currently connected.
    hyprctl monitors -j 2>/dev/null | jq -e --arg m "$mon" '.[] | select(.name == $m)' >/dev/null 2>&1 || continue

    if [ "$kind" = "video" ]; then
        pkill -f "mpvpaper .*$mon" 2>/dev/null
        mkdir -p /tmp/aeonshell-video-wp 2>/dev/null
        echo "$file" > "/tmp/aeonshell-video-wp/$mon"
        mpvpaper -o "no-audio loop-file=inf hwdec=auto vo=gpu gpu-context=wayland cache=no demuxer-max-bytes=32MiB demuxer-max-back-bytes=16MiB vd-lavc-threads=2 input-ipc-server=/tmp/aeonshell-mpv-$mon.sock" \
            "$mon" "$file" >/tmp/mpvpaper-restore.log 2>&1 &
        disown
    else
        pgrep -x awww-daemon >/dev/null 2>&1 || (awww-daemon >/tmp/awww-daemon.log 2>&1 & disown; sleep 0.4)
        awww img "$file" -o "$mon" >/tmp/awww-restore.log 2>&1
    fi
done
