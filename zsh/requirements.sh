#!/bin/bash
# name:		zsh.requirements.sh
# desc:		requirements for zsh module
# author:	Alex Candido <github:alxcsx>
set -e 
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.utils/packages.sh"

# --- Package Overrides ---
override_pkg "fd" "ubuntu" "fd-find"
override_pkg "fd" "debian" "fd-find"

# --- Custom Installers ---
custom_install "starship" "all" "curl -sS https://starship.rs/install.sh | sh"

# --- Execute Installation ---
require "eza"
require "bat"
require "ripgrep"
require "btop"
require "fzf"
require "fd"
require "zoxide"
require "starship"