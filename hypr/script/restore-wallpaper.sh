#!/usr/bin/env bash

HOME="${HOME:-/home/$(id -un)}"
STATE_DIR="$HOME/.cache/aeonshell/wallpaper-state"
LOG_DIR="/tmp"

[ -d "$STATE_DIR" ] || exit 0

wait_for_hyprland() {
    local tries=0
    while [ "$tries" -lt 20 ]; do
        if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
        tries=$((tries + 1))
    done
}
wait_for_hyprland

for state_file in "$STATE_DIR"/*; do
    [ -f "$state_file" ] || continue
    mon=$(basename "$state_file")
    line=$(cat "$state_file" 2>/dev/null)
    [ -z "$line" ] && continue

    kind="${line%%|*}"
    file="${line#*|}"
    [ -f "$file" ] || continue

    sock="/tmp/aeonshell-mpv-$mon.sock"

    if [ "$kind" = "video" ]; then
        if ! command -v mpvpaper >/dev/null 2>&1; then
            echo "$(date): mpvpaper not found, skipping video wallpaper for $mon" >> "$LOG_DIR/mpvpaper-restore.log"
            continue
        fi

        pkill -f "input-ipc-server=$sock" 2>/dev/null

        mkdir -p /tmp/aeonshell-video-wp 2>/dev/null
        echo "$file" > "/tmp/aeonshell-video-wp/$mon"

        if command -v awww >/dev/null 2>&1; then
            awww clear -o "$mon" >>"$LOG_DIR/awww-restore.log" 2>&1
        fi

        mpvpaper -o "no-audio loop-file=inf hwdec=auto vo=gpu gpu-context=wayland cache=no demuxer-max-bytes=32MiB demuxer-max-back-bytes=16MiB vd-lavc-threads=2 input-ipc-server=$sock" \
            "$mon" "$file" >>"$LOG_DIR/mpvpaper-restore.log" 2>&1 &
        disown
    else
        pkill -f "input-ipc-server=$sock" 2>/dev/null

        if ! command -v awww >/dev/null 2>&1; then
            echo "$(date): awww not found, skipping static wallpaper for $mon" >> "$LOG_DIR/awww-restore.log"
            continue
        fi

        if ! pgrep -x awww-daemon >/dev/null 2>&1; then
            awww-daemon >>"$LOG_DIR/awww-daemon.log" 2>&1 &
            disown
            sleep 0.4
        fi
        awww img "$file" -o "$mon" >>"$LOG_DIR/awww-restore.log" 2>&1
    fi
done
