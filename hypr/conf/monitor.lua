-- monitor.lua
-- -----------------------------------------------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- -----------------------------------------------------------

-- hl.on("hyprland.start", function()
--     hl.dispatch(hl.dsp.focus_monitor({ monitor = "DP-2" }))
--     hl.dispatch(hl.dsp.workspace({ workspace = "1" }))
-- end)