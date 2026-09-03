#!/usr/bin/env bash

HOME="${HOME:-/home/$(id -un)}"

TARGET_FILE="$HOME/.cache/wal/colors"
OUT_LUA="$HOME/.config/hypr/conf/colors-wal.lua"

INOTIFYWAIT_BIN="$(command -v inotifywait || echo /usr/bin/inotifywait)"

generate_colors() {
    if [ -f "$TARGET_FILE" ]; then
        # Берем строки 2 и 5
        color1=$(sed -n '2p' "$TARGET_FILE" | sed 's/#//')
        color2=$(sed -n '5p' "$TARGET_FILE" | sed 's/#//')
        
        echo "$(date): Color1=$color1, Color2=$color2" >> /tmp/colors-debug.log

        cat <<EOF > "$OUT_LUA"
-- colors-wal.lua
return {
  active_1 = "0xff${color1}",
  active_2 = "0xff${color2}",
}
EOF
        hyprctl reload
    fi
}

generate_colors

while true; do
    if [ -x "$INOTIFYWAIT_BIN" ]; then
        "$INOTIFYWAIT_BIN" -e modify "$TARGET_FILE" &> /dev/null
    else
        sleep 2
    fi
    generate_colors
done