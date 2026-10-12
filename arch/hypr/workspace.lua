local c = require("constants")

local prefixes = c.monitorWorkspacePrefix
if not next(prefixes) then
    -- Generic host (e.g. single monitor laptop): apply default prefix 1 rules
    prefixes = { [""] = 1 }
end

for monitorName, prefix in pairs(prefixes) do
    for i = 1, 9 do
        local preset = c.workspace_data_for_monitor(monitorName, i) or {}
        local rule = {
            workspace = preset.workspace,
            gaps_in = preset.gaps_in,
            gaps_out = preset.gaps_out,
            no_border = preset.no_border,
            no_rounding = preset.no_rounding,
            decorate = preset.decorate,
            default = preset.default,
            persistent = preset.persistent,
        }
        if monitorName ~= "" then
            rule.monitor = monitorName
        end

        hl.workspace_rule(rule)
    end
end