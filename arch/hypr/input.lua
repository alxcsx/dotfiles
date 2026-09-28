local c = require("constants")

hl.env("LC_CTYPE", "pt_BR.UTF-8")

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "intl",
        kb_model   = "pc104",
        kb_options = "",
        kb_rules   = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})


hl.bind(c.mainMod .. " + C", hl.dsp.window.close())
hl.bind(c.mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(c.mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
hl.bind(c.mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(c.mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(c.mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

hl.bind(c.mainMod .. " + T"		, hl.dsp.exec_cmd(c.terminal))
hl.bind(c.mainMod .. " + B"		, hl.dsp.exec_cmd(c.browser))
hl.bind(c.mainMod .. " + E"		, hl.dsp.exec_cmd(c.fileManager))
hl.bind(c.mainMod .. "+Space"	, hl.dsp.exec_cmd(c.ipc .. "panel-toggle launcher"))
hl.bind("ALT + TAB"				 	, hl.dsp.exec_cmd(c.ipc .. "window-switcher"))
-- Move focus with mainMod + arrow keys
hl.bind(c.mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(c.mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(c.mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(c.mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(c.mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(c.mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Tools
hl.bind(c.mainMod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | wl-copy'))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(c.mainMod .. " + " .. key, function() 
        local focus_payload = hl.dsp.focus({ workspace = c.workspace_for_active_monitor(i) });
        hl.dispatch(focus_payload)     
    end)
    hl.bind(c.mainMod .. " + SHIFT + " .. key, function() 
        local move_payload = hl.dsp.window.move({ workspace = c.workspace_for_active_monitor(i) });
        hl.dispatch(move_payload) 
    end)
end

hl.bind(c.mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
-- Scroll through existing workspaces with mainMod + scroll
hl.bind(c.mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(c.mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume" , hl.dsp.exec_cmd(c.ipc .. "volume-up"))
hl.bind("XF86AudioLowerVolume" , hl.dsp.exec_cmd(c.ipc .. "volume-down"))
hl.bind("XF86AudioMute"				 , hl.dsp.exec_cmd(c.ipc .. "volume-mute"))
hl.bind("XF86MonBrightnessUp"	 , hl.dsp.exec_cmd(c.ipc .. "brightness-up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(c.ipc .. "brightness-down"))

-- Requires playerctl
hl.bind("XF86AudioNext"	, hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay"	, hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev"	, hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
