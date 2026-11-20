-- Machine-specific hardware for this host (janga: dual-monitor desktop)
return {
    mainMonitor     = "DP-1",
    secondaryMonitor = "HDMI-A-1",
    monitorWorkspacePrefix = {
        ["DP-1"]    = 1,
        ["HDMI-A-1"] = 2,
    },
    monitors = {
        {
            output    = "HDMI-A-1",
            mode      = "preferred",
            position  = "0x0",
            transform = 1,
        },
        {
            output   = "DP-1",
            mode     = "2560x1440@180",
            position = "1080x0",
            scale    = 1,
        },
    },
}
