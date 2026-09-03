package.path = os.getenv("HOME") .. "/.config/hypr/conf/?.lua;" .. package.path

package.loaded["colors-wal"] = nil
local ok, wal = pcall(require, "colors-wal")
local c1 = (ok and wal and wal.active_1) and wal.active_1 or "0xee89b4fa"
local c2 = (ok and wal and wal.active_2) and wal.active_2 or "0xeecba6f7"

-- 0xAARRGGBB -> rgba(RRGGBBAA)
local function to_rgba(hex)
    local h = hex:gsub("^0x", "")
    local alpha = h:sub(1, 2)
    local rgb = h:sub(3)
    return "rgba(" .. rgb .. alpha .. ")"
end

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = { colors = { to_rgba(c1), to_rgba(c2) }, angle = 45 },
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
require("quickshell")