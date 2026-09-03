-- autostart.lua

hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY XAUTHORITY HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY XAUTHORITY HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("~/.config/hypr/script/colors_in_wallpaper.sh &")
  hl.exec_cmd("quickshell &")
  hl.exec_cmd("awww-daemon &")
  hl.exec_cmd("sleep 2 && ~/.config/hypr/script/restore-wallpaper.sh &")
  hl.exec_cmd("wl-paste --type text --watch cliphist store &")
  hl.exec_cmd("wl-paste --type image --watch cliphist store &")
end)