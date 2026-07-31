#!/bin/bash
# name:		zsh.requirements.sh
# desc:		requirements for zsh module
# author:	Alex Candido <github:alxcsx>
set -e 
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.utils/packages.sh"

echo "Installing ZSH requirements for OS: $OS | Distro: $DISTRO"
echo "---------------------------------------------------------"

# --- Package Overrides ---
override_pkg "fd" "ubuntu" "fd-find"
override_pkg "fd" "debian" "fd-find"

# --- Custom Installers ---
custom_install "starship" "all" "curl -sS https://starship.rs/install.sh | sh"
custom_install "mise" "all" "curl https://mise.run | sh"


# --- Execute Installation ---
require "eza"
require "bat"
require "ripgrep"
require "btop"
require "fzf"
require "fd"
require "mise"
require "zoxide"
require "starship"

echo "---------------------------------------------------------"
echo "Bootstrap complete!"