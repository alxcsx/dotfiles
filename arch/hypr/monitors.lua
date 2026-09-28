-- Monitor rules come from host.lua (override per machine via hosts/<hostname>/hypr/host.lua).
-- Generic hosts get no rules: Hyprland auto-configures (preferred mode, auto layout).
local c = require("constants")

for _, monitor in ipairs(c.host.monitors or {}) do
    hl.monitor(monitor)
end

hl.on("workspace.move_to_monitor", function(ws, m)
    hl.notification.create({
        text = "Workspace " .. ws.name .. " shifted to " .. m.name,
        timeout = 3000,
    })
end)
