#!/usr/bin/env bash

HOME="${HOME:-/home/$(id -un)}"
STATE_DIR="$HOME/.cache/aeonshell/wallpaper-state"

[ -d "$STATE_DIR" ] || exit 0

sleep 2

for state_file in "$STATE_DIR"/*; do
    [ -f "$state_file" ] || continue
    mon=$(basename "$state_file")
    line=$(cat "$state_file" 2>/dev/null)
    [ -z "$line" ] && continue

    kind="${line%%|*}"
    file="${line#*|}"
    [ -f "$file" ] || continue

    if [ "$kind" = "video" ]; then
        pkill -f "mpvpaper .*$mon" 2>/dev/null
        mkdir -p /tmp/aeonshell-video-wp 2>/dev/null
        echo "$file" > "/tmp/aeonshell-video-wp/$mon"
        
        awww clear -o "$mon" 2>/dev/null

        mpvpaper -o "no-audio loop-file=inf hwdec=auto vo=gpu gpu-context=wayland cache=no demuxer-max-bytes=32MiB demuxer-max-back-bytes=16MiB vd-lavc-threads=2 input-ipc-server=/tmp/aeonshell-mpv-$mon.sock" \
            "$mon" "$file" >/tmp/mpvpaper-restore.log 2>&1 &
        disown
    else
        pkill -f "mpvpaper .*$mon" 2>/dev/null
        pgrep -x awww-daemon >/dev/null 2>&1 || (awww-daemon >/tmp/awww-daemon.log 2>&1 & disown; sleep 0.4)
        awww img "$file" -o "$mon" >/tmp/awww-restore.log 2>&1
    fi
done