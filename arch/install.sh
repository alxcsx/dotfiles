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
