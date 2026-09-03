-- bind.lua

-- base
local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "pcmanfm-qt"
local browser = "zen-browser"

-- binds
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))

hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("qs ipc call launcher toggle"))

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag({ mode = "move" }))
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Workspaces
for i = 1, 5 do
    hl.bind(
        mainMod .. " + " .. i,
        hl.dsp.focus({ workspace = i })
    )
end

for i = 1, 5 do
    hl.bind(
        mainMod .. " + SHIFT + " .. i,
        hl.dsp.window.move({ workspace = i })
    )
end

-- Focus keyboard
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

-- Screenshot
hl.bind("F12", hl.dsp.exec_cmd("qs ipc call screenshot full"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("qs ipc call screenshot region"))

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"))

-- ALT + ENTER — fullscreen
hl.bind("ALT + Return", hl.dsp.window.fullscreen({ toggle = true }))

-- Spirit workspace scratchpad
hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special())
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special" }))

-- Other
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })