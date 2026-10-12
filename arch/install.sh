#!/usr/bin/env bash
# name:		arch.install.sh
# desc:		Configure the Linux desktop (Hyprland + Noctalia).
# author:	Alex Candido <github:alxcsx>

if false; then
	source "../dot.sh"
fi

assert [ "$OS" = "linux" ] -- \
	"Not on Linux" \
	"This Module Only Works on Linux Machines"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

link_dir_content "$MODULE_DIR/hypr" "$CONFIG_DIR/hypr"
link_dir_content "$MODULE_DIR/noctalia" "$CONFIG_DIR/noctalia"

# Machine-specific overrides (monitors, workspaces) — hosts/<hostname>/hypr/
HOST_DIR="$MODULE_DIR/hosts/$(uname -n)"
if [[ -d "$HOST_DIR" ]]; then
	link_dir_content "$HOST_DIR/hypr" "$CONFIG_DIR/hypr"
else
	printfln "${YELLOW}[!]${NC} No host overrides for '$(uname -n)'; using generic defaults."
fi

# Mid-install auto-reloads can catch a half-linked state; end on the complete config.
step --skip-if '[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]' \
	"Reload Hyprland config" \
	hyprctl reload

step "Sync Noctalia settings (base + host override)" \
	"$MODULE_DIR/noctalia-state/noctalia-sync" push

link_file -m "Link noctalia-sync" \
	"$MODULE_DIR/noctalia-state/noctalia-sync" "$HOME/.local/bin/noctalia-sync"
link_dir_content "$MODULE_DIR/noctalia-state/systemd" "$CONFIG_DIR/systemd/user"

USER_BUS='systemctl --user show-environment >/dev/null 2>&1' # no session -> skip
step --run-if "$USER_BUS" "Reload systemd user units" systemctl --user daemon-reload
step --run-if "$USER_BUS" "Enable noctalia-sync path unit" systemctl --user enable --now noctalia-sync.path
