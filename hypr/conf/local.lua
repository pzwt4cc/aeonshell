-- local.lua
-- Личный конфиг: настройки поведения окон, автозапуска и прочего

-- ==================================================
-- --- Язык ---
-- ==================================================

hl.env("LANG", "ru_RU.UTF-8")

-- ==================================================
-- --- NVIDIA ---
-- ==================================================

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")

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
    hl.exec_cmd("pgrep -x ydotoold > /dev/null || ydotoold &")

    hl.dispatch(hl.dsp.focus({ monitor = "DP-2" }))
    hl.dispatch(hl.dsp.focus({ workspace = "1" }))

    hl.exec_cmd("sleep 0.2 && ydotool mousemove -a 1600 400 && pkill -x ydotoold")

    hl.dispatch(hl.dsp.focus({ monitor = "DP-2" }))

    hl.exec_cmd("gsr-ui &")
    hl.exec_cmd("udiskie &")
    hl.exec_cmd("sleep 2 && vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland &")
    hl.exec_cmd("steam &")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 &")
    hl.exec_cmd("/usr/lib/oo7-daemon --replace &")
    hl.exec_cmd("/home/pzwt4cc/Projects/LEOBOG-GUI/run.sh --tray &")
    hl.exec_cmd("openrgb --profile 'MY' &")
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
-- --- Мониторы ---
-- ==================================================

hl.monitor({
    output = "DP-2",
    mode = "2560x1440@180",
    position = "0x0",
    scale = 1
})

hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60",
    position = "-1920x0",
    scale = 1
})

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
-- --- Рабочие столы ---
-- ==================================================

-- DP-2: основной монитор, 5 постоянных рабочих столов
hl.workspace_rule({
    workspace = "1",
    monitor = "DP-2",
    default = true,
    persistent = true
})

hl.workspace_rule({
    workspace = "2",
    monitor = "DP-2",
    persistent = true
})

hl.workspace_rule({
    workspace = "3",
    monitor = "DP-2",
    persistent = true
})

hl.workspace_rule({
    workspace = "4",
    monitor = "DP-2",
    persistent = true
})

hl.workspace_rule({
    workspace = "5",
    monitor = "DP-2",
    persistent = true
})

-- HDMI-A-1: отдельный монитор, только свой workspace
hl.workspace_rule({
    workspace = "6",
    monitor = "HDMI-A-1",
    default = true,
    persistent = true
})

-- ==================================================
-- --- Правила окон ---

-- hyprctl clients | grep -A2 class
-- ==================================================

local floatRules = {
    { class = "codium",                                          size = "1500 1000" },
    { class = "dev.zed.Zed",                                     size = "1500 1000" },
    { class = "vesktop",                                         size = "1500 900"  },
    { class = "org.xfce.mousepad",                               size = "800 600"   },
    { class = "org.telegram.desktop",                            size = "1500 900"  },
    { class = "openrgb",                                         size = "1200 900"  },
    { class = "mpv",                                             size = "900 700"   },
    { class = "zen",                                             size = "1400 900"  },
    { class = "helium",                                          size = "1400 900"  },
    { class = "localsend",                                       size = "1400 900"  },
    { class = "twintaillauncher",                                size = "1280 720"  },
    { class = "org.gnome.Loupe",                                 size = "1200 780"  },
    { class = "org.gnome.Calculator",                            size = "395 616"   },
    { class = "warp-taskbar",                                    size = "750 660"   },
    { class = "Spotify",                                         size = "1570 990"  },
    { class = "org.mozilla.Thunderbird",                         size = "1570 990"  },
    { class = "xdg-desktop-portal-gtk",                          size = "925 635"   },
    { class = "io.github.elyprismlauncher.ElyPrismLauncher",     size = "1350 900"  },
    { class = "DBeaver",                                         size = "1500 1000" },
    { class = "local",                                           size = "1300 900"  },
    { class = "gimp",                                            size = "1550 950"  },
    { class = "system-config-printer",                           size = "650 450"   },
    { class = "GParted",                                         size = "1200 500"  },
    { class = "org.keepassxc.KeePassXC",                         size = "850 600"   },
    { class = "octopi",                                          size = "1075 700"  },
    { class = "org.localsend.localsend_app",                     size = "1270 830"  },
    { class = "YouTube Music Desktop App",                       size = "1570 990"  },
    { class = "org.qbittorrent.qBittorrent",                     size = "1500 1000" },
}

for _, rule in ipairs(floatRules) do
    hl.window_rule({
        match = { class = rule.class },
        float = true,
        size = rule.size,
    })
end