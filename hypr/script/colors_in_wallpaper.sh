#!/usr/bin/env bash

# Абсолютный HOME на случай, если переменная вдруг не установлена
# в момент запуска (например, из exec-once с урезанным окружением).
HOME="${HOME:-/home/$(id -un)}"

TARGET_FILE="$HOME/.cache/wal/colors"
OUT_FILE="$HOME/.config/hypr/script/colors-wal.conf"

# Абсолютные пути к бинарям вместо голых имён — так скрипт не зависит
# от того, насколько полный $PATH прокинут в окружение, из которого
# его запустили.
HYPRCTL_BIN="$(command -v hyprctl || echo /usr/bin/hyprctl)"
INOTIFYWAIT_BIN="$(command -v inotifywait || echo /usr/bin/inotifywait)"

generate_colors() {
    if [ -f "$TARGET_FILE" ]; then
        color1=$(sed -n '2p' "$TARGET_FILE" | sed 's/#//')
        color2=$(sed -n '5p' "$TARGET_FILE" | sed 's/#//')

        cat <<EOF > "$OUT_FILE"
\$color_active_1 = rgba(${color1}ff)
\$color_active_2 = rgba(${color2}ff)
EOF
        "$HYPRCTL_BIN" reload
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
