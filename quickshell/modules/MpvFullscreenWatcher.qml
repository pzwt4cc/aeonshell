pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    Process {
        id: fullscreenPauseListener
        running: true
        command: ["bash", "-c",
            "trap 'kill 0 2>/dev/null' EXIT TERM INT; " +
            "sig=\"$HYPRLAND_INSTANCE_SIGNATURE\"; " +
            "rt=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\"; " +
            "sock=\"$rt/hypr/$sig/.socket2.sock\"; " +
            "[ -S \"$sock\" ] || exit 0; " +
            "socat -U - UNIX-CONNECT:\"$sock\" 2>/dev/null | while IFS= read -r line; do " +
            "  case \"$line\" in " +
            "    fullscreen\\>\\>*|activewindow\\>\\>*|activewindowv2\\>\\>*) ;; " +
            "    *) continue ;; " +
            "  esac; " +
            "  aw=$(hyprctl activewindow -j 2>/dev/null); " +
            "  [ -z \"$aw\" ] && continue; " +
            "  fs=$(echo \"$aw\" | jq -r '.fullscreen // 0'); " +
            "  monid=$(echo \"$aw\" | jq -r '.monitor // empty'); " +
            "  [ -z \"$monid\" ] && continue; " +
            "  monname=$(hyprctl monitors -j 2>/dev/null | jq -r --arg id \"$monid\" '.[] | select(.id == ($id|tonumber)) | .name'); " +
            "  [ -z \"$monname\" ] && continue; " +
            "  msock=\"/tmp/aeonshell-mpv-$monname.sock\"; " +
            "  [ -S \"$msock\" ] || continue; " +
            "  if [ \"$fs\" != \"0\" ] && [ \"$fs\" != \"null\" ]; then " +
            "    echo '{\"command\":[\"set_property\",\"pause\",true]}' | socat - UNIX-CONNECT:\"$msock\" >/dev/null 2>&1; " +
            "  else " +
            "    echo '{\"command\":[\"set_property\",\"pause\",false]}' | socat - UNIX-CONNECT:\"$msock\" >/dev/null 2>&1; " +
            "  fi; " +
            "done"]

        Component.onDestruction: {
            fullscreenPauseListener.running = false
        }
    }
}
