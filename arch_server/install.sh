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
