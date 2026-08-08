#!/bin/bash
# name:		dev.requirements.sh
# desc:		requirements for dev module
# author:	Alex Candido <github:alxcsx>
set -e
# shellcheck source=.utils/packages.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.utils/packages.sh"

# Editor
override_pkg "emacs" "macos" "d12frosted/emacs-plus/emacs-plus-app"
require "emacs"

# GPG Integration
override_pkg "pinentry" "macos" "pinentry-mac"
require "pinentry"

# Fonts
# -- macOS Overrides
override_pkg "roboto-mono" "macos" "font-roboto-mono"
override_pkg "victor-mono" "macos" "font-victor-mono"
override_pkg "symbols-nerd-font" "macos" "font-symbols-only-nerd-font"

# -- Arch Linux Overrides
override_pkg "roboto-mono" "arch" "ttf-roboto-mono"
override_pkg "victor-mono" "arch" "ttf-victor-mono"
override_pkg "symbols-nerd-font" "arch" "ttf-nerd-fonts-symbols-mono"

require "roboto-mono" --cask
require "victor-mono" --cask --aur
require "symbols-nerd-font" --cask
