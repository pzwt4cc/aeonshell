package.path = os.getenv("HOME") .. "/.config/hypr/conf/?.lua;" .. package.path

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(89b4faee)", "rgba(cba6f7ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
    }
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
