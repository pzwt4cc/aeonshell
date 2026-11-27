-- local.lua
-- Личный конфиг: переопределите мониторы, раскладку, автозапуск и правила окон под свою систему

-- ==================================================
-- --- Язык (по умолчанию берётся системная локаль) ---
-- ==================================================

-- hl.env("LANG", "ru_RU.UTF-8")

-- ==================================================
-- --- Курсор ---
-- ==================================================

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

-- ==================================================
-- --- Автозапуск ---
-- ==================================================

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 &")
    hl.exec_cmd("udiskie &")

    -- Примеры личного автозапуска:
    -- hl.dispatch(hl.dsp.focus({ monitor = "DP-2" }))
    -- hl.dispatch(hl.dsp.focus({ workspace = "1" }))
    -- hl.exec_cmd("sleep 2 && vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland &")
    -- hl.exec_cmd("steam &")
end)

-- ==================================================
-- --- Клавиатура ---
-- ==================================================

hl.config({
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:alt_shift_toggle"
    }
})

-- ==================================================
-- --- Мониторы и рабочие столы (пример для 2 мониторов) ---
-- По умолчанию используется автоопределение из conf/monitor.lua
-- ==================================================

-- hl.monitor({
--     output = "DP-2",
--     mode = "2560x1440@180",
--     position = "0x0",
--     scale = 1
-- })
--
-- hl.monitor({
--     output = "HDMI-A-1",
--     mode = "1920x1080@60",
--     position = "-1920x0",
--     scale = 1
-- })
--
-- hl.workspace_rule({ workspace = "1", monitor = "DP-2", default = true, persistent = true })
-- hl.workspace_rule({ workspace = "2", monitor = "DP-2", persistent = true })
-- hl.workspace_rule({ workspace = "3", monitor = "DP-2", persistent = true })
-- hl.workspace_rule({ workspace = "4", monitor = "DP-2", persistent = true })
-- hl.workspace_rule({ workspace = "5", monitor = "DP-2", persistent = true })
-- hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-1", default = true, persistent = true })

-- ==================================================
-- --- X11 / Steam ---
-- ==================================================

hl.window_rule({
    "nomaxsize",
    match = { class = "^[S|s]team$" }
})

hl.window_rule({
    "move cursor -50% -50%",
    match = { class = "^[S|s]team$", title = "^$" }
})

hl.window_rule({
    "move cursor -50% -50%",
    match = { class = "^[S|s]team$", title = "notificationtoasts.*" }
})

-- ==================================================
-- --- Примеры плавающих окон (дополняйте под свои программы) ---
-- hyprctl clients -j | jq -r '.[] | "\(.class): \(.size)"'
-- ==================================================

local floatRules = {
    { class = "org.telegram.desktop",        size = "1400 900" },
    { class = "org.gnome.Loupe",             size = "1200 780" },
    { class = "org.gnome.Calculator",        size = "395 616" },
    { class = "xdg-desktop-portal-gtk",      size = "925 635" },
    { class = "org.localsend.localsend_app", size = "1270 830" },
}

for _, rule in ipairs(floatRules) do
    hl.window_rule({
        match = { class = rule.class },
        float = true,
        size = rule.size,
    })
end
