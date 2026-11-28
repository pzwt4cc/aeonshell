-- windowrules.lua

local rules = {
    { name = "float-kitty",                class = "kitty",                size = "1070 700" },
    { name = "float-quickshell",           class = "org.quickshell" },
    { name = "float-nm-connection-editor", class = "nm-connection-editor", size = "600 400" },
}

for _, r in ipairs(rules) do
    hl.window_rule({
        name = r.name,
        match = { class = r.class },
        float = true,
        size = r.size,
    })
end
