#!/bin/bash
# name:		zsh.requirements.sh
# desc:		requirements for zsh module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../.utils/packages_v2.sh"
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

require_custom -c "starship" -- run_remote_script https://starship.rs/install.sh
