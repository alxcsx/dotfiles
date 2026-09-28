#!/bin/bash
# name:		arch.requirements.sh
# desc:		requirements for arch module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

assert [ "$OS" = "linux" ] -- \
  "Not on Linux" \
  "This Module Only Works on Linux Machines"

# --- Desktop Stack ---
require_pkgs \
  hyprland \
  uwsm \
  hyprpolkitagent \
  xdg-desktop-portal-hyprland \
  grim \
  slurp \
  wl-clipboard \
  playerctl \
  gnome-keyring \
  glib2 \
  nemo \
  dunst \
  aur:noctalia-git \
  aur:zen-browser-bin
