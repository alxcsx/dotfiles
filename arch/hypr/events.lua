hl.on("workspace.move_to_monitor", function(ws, m)
    hl.notification.create({ 
        text = "Workspace " .. ws.name .. " shifted to " .. m.name, 
        timeout = 3000 
    })
end)