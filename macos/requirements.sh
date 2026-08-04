#!/bin/bash
# name:		macos.requirements.sh
# desc:		requirements for macos module
# author:	Alex Candido <github:alxcsx>
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.utils/packages.sh"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "Not on macOS. Skipping macos requirements."
    exit 0
fi

echo "Installing macOS specific dependencies..."

# --- Xcode Command Line Tools ---
xcode-select -p >/dev/null 2>&1 || sudo xcode-select --install

# --- Ricing ---
require FelixKratz/formulae/sketchybar
require FelixKratz/formulae/borders
require asmvik/formulae/yabai
require fastfetch
# --- Shell tools
require karabiner-elements --cask 
require yqrashawn/goku/goku
require abue-ammar/tinycast/tinycast --cask  # Launcher
# --- APPS
require zen-browser --cask
require iina        --cask  # Media Player
require itsycal     --cask	# Calendar
require pearcleaner --cask
# --- FONTS
require font-fira-code-nerd-font --cask
require font-hack-nerd-font --cask
require font-jetbrains-mono-nerd-font --cask
require font-roboto-mono-nerd-font --cask