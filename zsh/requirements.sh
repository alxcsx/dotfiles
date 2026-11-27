#!/bin/bash
# name:		zsh.requirements.sh
# desc:		requirements for zsh module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

require_pkgs \
  zsh \
  eza \
  bat \
  ripgrep \
  btop \
  fzf \
  fd \
  zoxide

if ! (command -v pacman >/dev/null 2>&1 && pacman -Qq starship >/dev/null 2>&1); then
  step "Install or update starship" run_remote_script https://starship.rs/install.sh -y
fi
