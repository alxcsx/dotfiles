local c = require("constants")

for monitorName, prefix in pairs(c.monitorWorkspacePrefix) do
    for i = 1, 9 do
        local preset = c.workspace_data_for_monitor(monitorName, i) or {}

        hl.workspace_rule({
            workspace = preset.workspace,
            -- default_name = preset.workspace,
            monitor = monitorName,
            gaps_in = preset.gaps_in,
            gaps_out = preset.gaps_out,
            no_border = preset.no_border,
            no_rounding = preset.no_rounding,
            decorate = preset.decorate,
            default = preset.default,
            persistent = preset.persistent,
        })
    end
end

local workspaceWindowRules = {
    [c.workspace_for_monitor(1,1)] = { class = "^(zen.*)$" },
    [c.workspace_for_monitor(1,2)] = { class = "^([Cc]ode|[Vv]scodium)$" },
    [c.workspace_for_monitor(1,3)] = { class = "^([Dd]iscord|[Vv]esktop|WebCord)$" },
    [c.workspace_for_monitor(1,4)] = { class = "^([Ss]team|steamwebhelper)$" },
}

-- for workspaceName, match in pairs(workspaceWindowRules) do
--     hl.window_rule({
--         match = match,
--         workspace = "name:" .. workspaceName,
--     })
-- end