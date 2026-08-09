#!/bin/bash
# name:		dev.requirements.sh
# desc:		requirements for dev module
# author:	Alex Candido <github:alxcsx>
set -e
# shellcheck source=.utils/packages.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.utils/packages.sh"

# Editor
override_pkg "emacs" "macos" "emacs-plus --with-dbus --with-mailutils --with-xwidgets"
if [[ "$DISTRO" == "macos" ]]; then
	printfln "${GREEN}[*]${NC} Tapping emacs-plus for macOS..."
	brew tap d12frosted/emacs-plus
	brew trust d12frosted/emacs-plus
fi

require "emacs"

# GPG Integration
override_pkg "pinentry" "macos" "pinentry-mac"
require "pinentry"

# Fonts
# -- macOS Overrides
override_pkg "jetbrains-mono" "macos" "font-jetbrains-mono"
override_pkg "victor-mono" "macos" "font-victor-mono"
override_pkg "symbols-nerd-font" "macos" "font-symbols-only-nerd-font"

# -- Arch Linux Overrides
override_pkg "jetbrains-mono" "arch" "ttf-jetbrains-mono"
override_pkg "victor-mono" "arch" "ttf-victor-mono"
override_pkg "symbols-nerd-font" "arch" "ttf-nerd-fonts-symbols-mono"

require "jetbrains-mono" --cask
require "victor-mono" --cask --aur
require "symbols-nerd-font" --cask
