package.path = os.getenv("HOME") .. "/.config/hypr/conf/?.lua;" .. package.path

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 0,
    },
})

-- =========================================================================================

-- IMPORTS

require("env")
require("monitor")
require("autostart")
require("bind")
require("keyboard")
require("animation")
require("windowrules")
require("misc")
require("local")
