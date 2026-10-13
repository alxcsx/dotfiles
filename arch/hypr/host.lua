-- Machine-specific hardware. Generic by default (laptop / unknown hosts):
-- no monitor rules -> Hyprland auto-configures (preferred mode, auto layout).
-- To pin monitors/workspaces for a machine, add hosts/<hostname>/hypr/host.lua
-- Optional keyboard field: { keyboard = { layout = "br,us", variant = "abnt2,intl" } }
-- (first layout listed is the boot default; Alt+Shift toggles between them)
return {}
