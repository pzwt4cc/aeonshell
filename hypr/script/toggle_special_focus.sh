#!/usr/bin/env bash
# Переключает спец-воркспейс и, если после переключения он оказался
# видимым, явно фокусирует окно внутри него по адресу.
#
# Зачем: hyprctl dispatch togglespecialworkspace сам по себе может открыть
# воркспейс, не передав ему клавиатурный фокус (известная особенность
# Hyprland, см. hyprwm/Hyprland issues #4048, #7116) — окно видно, но
# нажатия уходят мимо (в игру/приложение, которое было активно раньше).
#
# В отличие от "костыля" через focuscurrentorlast (который просто
# альт-табает между последними двумя окнами и потому ломает навигацию),
# этот скрипт находит конкретное окно в спец-воркспейсе и фокусирует
# именно его — никаких побочных эффектов на остальные окна.

# Абсолютные пути к бинарям — чтобы скрипт не зависел от того,
# насколько полный $PATH прокинут в окружение, из которого его запустили.
HYPRCTL_BIN="$(command -v hyprctl || echo /usr/bin/hyprctl)"
JQ_BIN="$(command -v jq || echo /usr/bin/jq)"

"$HYPRCTL_BIN" dispatch togglespecialworkspace

# Небольшая пауза, чтобы Hyprland успел обновить состояние воркспейсов
# перед тем, как мы будем его опрашивать.
sleep 0.05

# Имя активного спец-воркспейса на текущем сфокусированном мониторе.
# Пустая строка/null означает, что спец-воркспейс сейчас скрыт —
# тогда фокусировать нечего, ничего не делаем.
special_name=$("$HYPRCTL_BIN" monitors -j | "$JQ_BIN" -r '.[] | select(.focused==true) | .specialWorkspace.name')

if [ -n "$special_name" ] && [ "$special_name" != "null" ]; then
    addr=$("$HYPRCTL_BIN" clients -j | "$JQ_BIN" -r --arg ws "$special_name" \
        '[.[] | select(.workspace.name==$ws)][0].address')

    if [ -n "$addr" ] && [ "$addr" != "null" ]; then
        "$HYPRCTL_BIN" dispatch focuswindow "address:$addr"
    fi
fi
