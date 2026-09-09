#!/usr/bin/env bash

HYPRCTL_BIN="/usr/bin/hyprctl"

if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo "HYPRLAND_INSTANCE_SIGNATURE is empty, are we inside Hyprland?" >&2
    exit 1
fi

"$HYPRCTL_BIN" dispatch togglespecialworkspace

special_name=""
tries=0
while [ "$tries" -lt 10 ]; do
    special_name=$("$HYPRCTL_BIN" monitors -j | jq -r '[.[] | select(.focused==true)][0].specialWorkspace.name // empty')
    [ -n "$special_name" ] && break
    sleep 0.03
    tries=$((tries + 1))
done

if [ -n "$special_name" ] && [ "$special_name" != "null" ]; then
    addr=$("$HYPRCTL_BIN" clients -j | jq -r --arg ws "$special_name" \
        '[.[] | select(.workspace.name==$ws)][0].address // empty')

    if [ -n "$addr" ] && [ "$addr" != "null" ]; then
        "$HYPRCTL_BIN" dispatch focuswindow "address:$addr"
    fi
fi
