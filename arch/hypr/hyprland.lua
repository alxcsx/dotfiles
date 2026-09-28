require("monitors")
require("input")
require("visuals")
require("workspace")
require("events")
local c = require("constants")
-------------------------------
----       AUTOSTART       ----
-------------------------------

hl.on("hyprland.start", function ()
    hl.dsp.focus({ workspace = c.workspace_for_monitor(1,1)})

    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")

    hl.exec_cmd("noctalia")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

hl.env("XCURSOR_SIZE", "18")
hl.env("HYPRCURSOR_SIZE", "18")
hl.env("GDK_SCALE", "1.5")
hl.env("GDK_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_THEME", "Adwaita:dark")

-------------------------------
----         MISC          ----
-------------------------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
    xwayland = {
        force_zero_scaling = true,
    }
})

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule{
	name = "floating-file-picker",
	match = {
		class = "^(xdg-desktop-portal-gtk)$",
	},
	float = true,
	center = true,
	size = { 800,600},
}

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- For Noctalia Color templates
require("noctalia").apply_theme()
