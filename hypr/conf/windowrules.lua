-- windowrules.lua

local rules = {
    { name = "float-kitty", class = "kitty", size = "1070 700" },
    { name = "float-quickshell", class = "org.quickshell", size = "870 660" },
    { name = "float-blueman-manager", class = "blueman-manager", size = "750 450" },
    { name = "float-pavucontrol", class = "org.pulseaudio.pavucontrol", size = "750 450" },
    { name = "float-pcmanfm-qt", class = "pcmanfm-qt", size = "1050 710" },
    { name = "float-nm-connection-editor", class = "nm-connection-editor", size = "600 400" },
    { name = "float-waypaper", class = "waypaper", size = "900 700" },
    { name = "float-peazip", class = "peazip", size = "1300 900" },
}

for _, r in ipairs(rules) do
    hl.window_rule({
        name = r.name,
        match = { class = r.class },
        float = true,
        size = r.size,
    })
end