#!/usr/bin/env bash

HOME="${HOME:-/home/$(id -un)}"

TARGET_FILE="$HOME/.cache/wal/colors"
OUT_LUA="$HOME/.config/hypr/conf/colors-wal.lua"

DEBUG_LOG="/tmp/colors-debug.log"
MAX_LOG_SIZE=$((1024 * 1024))

INOTIFYWAIT_BIN="$(command -v inotifywait || echo /usr/bin/inotifywait)"
HYPRCTL_BIN="$(command -v hyprctl || echo /usr/bin/hyprctl)"

HEX_RE='^[0-9a-fA-F]{6}$'

rotate_log_if_needed() {
    if [ -f "$DEBUG_LOG" ]; then
        local size
        size=$(stat -c%s "$DEBUG_LOG" 2>/dev/null || echo 0)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            : > "$DEBUG_LOG"
        fi
    fi
}

generate_colors() {
    [ -f "$TARGET_FILE" ] || return 0

    local line_count
    line_count=$(wc -l < "$TARGET_FILE")
    if [ "$line_count" -lt 5 ]; then
        echo "$(date): TARGET_FILE has only $line_count lines, skipping" >> "$DEBUG_LOG"
        return 0
    fi

    color1=$(sed -n '2p' "$TARGET_FILE" | tr -d '#[:space:]')
    color2=$(sed -n '5p' "$TARGET_FILE" | tr -d '#[:space:]')

    if ! [[ "$color1" =~ $HEX_RE ]] || ! [[ "$color2" =~ $HEX_RE ]]; then
        echo "$(date): invalid colors, color1=$color1 color2=$color2, skipping" >> "$DEBUG_LOG"
        return 0
    fi

    rotate_log_if_needed
    echo "$(date): Color1=$color1, Color2=$color2" >> "$DEBUG_LOG"

    cat <<EOF > "$OUT_LUA"
-- colors-wal.lua
return {
  active_1 = "0xff${color1}",
  active_2 = "0xff${color2}",
}
EOF

    if [ -x "$HYPRCTL_BIN" ]; then
        "$HYPRCTL_BIN" reload
    else
        echo "$(date): hyprctl not found, cannot reload" >> "$DEBUG_LOG"
    fi
}

generate_colors

while true; do
    if [ -x "$INOTIFYWAIT_BIN" ]; then
        if [ -f "$TARGET_FILE" ]; then
            "$INOTIFYWAIT_BIN" -e modify,close_write "$TARGET_FILE" &> /dev/null
            sleep 0.3
        else
            sleep 2
        fi
    else
        sleep 2
    fi
    generate_colors
done
