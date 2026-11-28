#!/usr/bin/env bash

if false; then
  source "../dot.sh"
fi

assert [ "$OS" = "linux" ] -- \
  "Not on Linux" \
  "This module only works on Linux"

step "Enable tailscaled service" sudo systemctl enable --now tailscaled

TS_OPERATOR="${SUDO_USER:-$USER}"
TS_FLAGS=(--operator="$TS_OPERATOR" --ssh --hostname="$(uname -n)")

if tailscale status >/dev/null 2>&1; then
  step "Sync Tailscale configuration" sudo tailscale set --operator="$TS_OPERATOR" --ssh
elif [[ -n "$TAILSCALE_AUTHKEY" ]]; then
  step "Authenticate Tailscale via auth-key" sudo tailscale up --auth-key="$TAILSCALE_AUTHKEY" "${TS_FLAGS[@]}"
else
  step -I "Authenticate Tailscale via login URL" sudo tailscale up "${TS_FLAGS[@]}"
fi

step "Enable sshd service" sudo systemctl enable --now sshd

step "Install logind server power config" \
  sudo install -Dm644 "$MODULE_DIR/10-server-lid.conf" /etc/systemd/logind.conf.d/10-server-lid.conf

step "Reload systemd-logind" sudo systemctl reload systemd-logind

if [[ -f /etc/kernel/cmdline ]] && ! grep -q "consoleblank=" /etc/kernel/cmdline; then
  step "Add consoleblank=60 to /etc/kernel/cmdline" \
    sudo sed -i 's/$/ consoleblank=60/' /etc/kernel/cmdline
  step "Regenerate UKI initramfs" sudo mkinitcpio -P
fi

SERVER_BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
SERVER_UNITS="$HOME/.config/systemd/user"
units_changed=0

install_server_submodule() {
  local sub="$1" label="$2"
  shift 2
  ask_yn "Install $sub submodule ($label)?" n || return 0

  mkdir -p "$SERVER_BIN_DIR" "$SERVER_UNITS"
  local tool unit
  for tool in "$@"; do
    link_file "$MODULE_DIR/$sub/$tool" "$SERVER_BIN_DIR/$tool"
  done
  for unit in "$MODULE_DIR/$sub"/*.service "$MODULE_DIR/$sub"/*.timer; do
    [ -e "$unit" ] || continue
    link_file "$unit" "$SERVER_UNITS/$(basename "$unit")"
    units_changed=1
  done
}

install_server_submodule "minecraft_server" "Minecraft join gate & password rotation" \
  mc-gate mc-password mc-rotate-password.sh mc-sync-verified mc-verified

install_server_submodule "network" "Cloudflare DDNS, WAN check, file share, healthguard" \
  cloudflare-ddns.py wan-check share exo-healthguard

install_server_submodule "backup" "Restic off-site backup, btrfs snapshots, weekly scan" \
  backup.sh btrfs-snapshot.sh maintenance-scan.sh

if ask_yn "Install static-sites submodule (Caddy + File Browser Quadlets)?" n; then
  QUADLET_DIR="$HOME/.config/containers/systemd"
  mkdir -p "$QUADLET_DIR"
  for q in "$MODULE_DIR/static-sites"/*.container; do
    [ -e "$q" ] || continue
    link_file "$q" "$QUADLET_DIR/$(basename "$q")"
  done
  units_changed=1
fi

if [ "$units_changed" = 1 ]; then
  step "Reload systemd user units" systemctl --user daemon-reload
fi
