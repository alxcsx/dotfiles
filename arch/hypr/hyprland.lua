require("monitors")
require("input")
require("visuals")
require("workspace")
local c = require("constants")
-------------------------------
----       AUTOSTART       ----
-------------------------------

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")

    hl.exec_cmd("noctalia")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

hl.env("XCURSOR_SIZE", "18")
hl.env("HYPRCURSOR_SIZE", "18")
hl.env("GDK_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-------------------------------
----         MISC          ----
-------------------------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        -- single-shot: persistent (2) yanks every new window, including X11 mode-less
        -- popups, back to the workspace the process was launched from.
        initial_workspace_tracking = 1,
        initial_workspace_token_timeout = 60,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
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

-- Fix Unity Editor dropdowns, popups and dialogs
-- Unity menus are real X11 toplevels, not override-redirect popups: they need input
-- immediately (else Unity closes them) and Unity's own global coords are wrong on
-- multi-monitor, so selectors are placed at the cursor instead.
local unity_selector_pos = { "cursor_x - (window_w * 0.5)", "cursor_y - (window_h * 0.5)" }

hl.window_rule({
    name  = "unity-input",
    match = { class = "^([Uu]nity.*)$" },
    allows_input = true,
})

hl.window_rule({
    name  = "unity-tooltips",
    match = { class = "^([Uu]nity.*)$", initial_title = "UnityTooltipWindow" },
    allows_input = false, no_focus = true, no_initial_focus = true, focus_on_activate = false,
})

hl.window_rule({
    name = "unity-add-component",
    match = {
        class = "^([Uu]nity.*)$",
        initial_title = "UnityEditor.AddComponent.AddComponentWindow",
    },
    move  = unity_selector_pos,
    float = true,
})

hl.window_rule({
    name = "unity-advanced-dropdown",
    match = {
        class = "^([Uu]nity.*)$",
        initial_title = "UnityEditor.IMGUI.Controls.AdvancedDropdownWindow",
    },
    move  = unity_selector_pos,
    float = true,
})

hl.window_rule({
    name = "unity-dialogs",
    match = {
        class = "^([Uu]nity.*)$",
        title = "^(Project Settings|Preferences|Package Manager|UI Toolkit Debugger|Font Asset Creator|Background Tasks)$",
    },
    float = true,
    min_size = { 300, 300 },
})

hl.window_rule({
    name = "unity-color-picker",
    match = {
        class = "^([Uu]nity.*)$",
        title = "^(Color|HDR Color)$",
    },
    float = true,
    move = "cursor 0 0",
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
	name  = "satty",
	match = { class = "^(com\\.gabm\\.satty)$" },
	float = true,
	center = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- For Noctalia Color templates
require("noctalia").apply_theme()
