#!/usr/bin/env bash

HYPRCTL_BIN="/usr/bin/hyprctl"
SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE"

env HYPRLAND_INSTANCE_SIGNATURE="$SIGNATURE" "$HYPRCTL_BIN" dispatch togglespecialworkspace

sleep 0.05

special_name=$(env HYPRLAND_INSTANCE_SIGNATURE="$SIGNATURE" "$HYPRCTL_BIN" monitors -j | jq -r '.[] | select(.focused==true) | .specialWorkspace.name')

if [ -n "$special_name" ] && [ "$special_name" != "null" ]; then
    addr=$(env HYPRLAND_INSTANCE_SIGNATURE="$SIGNATURE" "$HYPRCTL_BIN" clients -j | jq -r --arg ws "$special_name" \
        '[.[] | select(.workspace.name==$ws)][0].address')

    if [ -n "$addr" ] && [ "$addr" != "null" ]; then
        env HYPRLAND_INSTANCE_SIGNATURE="$SIGNATURE" "$HYPRCTL_BIN" dispatch focuswindow "address:$addr"
    fi
fi