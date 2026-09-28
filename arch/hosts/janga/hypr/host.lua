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
            output   = "DP-1",
            mode     = "2560x1440@180",
            position = "auto",
            scale    = "auto",
        },
        {
            output   = "HDMI-A-1",
            position = "auto-left",
            transform = 1,
        },
    },
}
