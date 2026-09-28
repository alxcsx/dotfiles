-- Monitor/workspace layout comes from host.lua (override via hosts/<hostname>/hypr/host.lua)
local host = require("host")

local mainMonitor = host.mainMonitor
local secondaryMonitor = host.secondaryMonitor
local monitorWorkspacePrefix = host.monitorWorkspacePrefix or {}
local workspacePresets = {
    [1] = {
        [1] = {
            workspace = "name:browsing",
            gaps_in = 8,
            gaps_out = 12,
            persistent = true,
            default = true,
        },
        [2] = {
            workspace = "name:coding",
            gaps_in = 1,
            gaps_out = 1,
            decorate = true,
            persistent = true,
        },
        [3] = {
            workspace = "name:social",
            gaps_in = 6,
            gaps_out = 10,
            persistent = true,
        },
        [4] = {
            workspace = "name:gaming",
            gaps_in = 1,
            gaps_out = 1,
            persistent = true,
        },
    },
  [2] = {
    [1] = {
        workspace = "name:misc",
        persistent = true,
        default = true,
    },
    [2] = {
        workspace = "name:misc II",
        persistent = true,
    },
    [3] = {
        workspace = "name:misc III",
        persistent = true,
    },
  }
}

local function workspace_data_for_monitor(monitorName, index)
    -- Unknown monitor (laptop eDP-1, or numeric calls) falls back to preset set 1
    local prefix = monitorWorkspacePrefix[monitorName] or 1
    if workspacePresets[prefix] and workspacePresets[prefix][index] then
        local preset =  workspacePresets[prefix][index]
        if not preset.workspace then
            preset.workspace = string.format("name:%d_%d", prefix, index)
        end
        return preset
    else
        return { workspace = string.format("name:%d_%d", prefix, index)  }
    end
end

local function workspace_for_monitor(monitorName, index)
    local preset = workspace_data_for_monitor(monitorName, index)
    return preset.workspace
end

local function workspace_for_active_monitor(index)
    local activeMonitor = hl.get_active_monitor()
    local monitorName = activeMonitor and activeMonitor.name or mainMonitor
    return workspace_for_monitor(monitorName, index)
end


return {
    host                          = host,
    monitorWorkspacePrefix        = monitorWorkspacePrefix,
    workspacePresets              = workspacePresets,
    mainMod                      = "SUPER",
    terminal                     = "kitty",
    fileManager                  = "nemo",
    browser                      = "zen-browser",
    ipc                          = "noctalia msg ",
    workspace_for_active_monitor = workspace_for_active_monitor,
    workspace_for_monitor        = workspace_for_monitor,
    workspace_data_for_monitor   = workspace_data_for_monitor,
    mainMonitor                  = mainMonitor,
    secondaryMonitor             = secondaryMonitor,
}
