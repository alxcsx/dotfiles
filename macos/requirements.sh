#!/bin/bash
# name:		macos.requirements.sh
# desc:		requirements for macos module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../.utils/common_v2.sh"
  source "../.utils/packages_v2.sh"
fi

assert [ "$OS" = "darwin" ] -- \
  "Not on MACOS" \
  "This Module Only Works on Darwin Machines"

step "Install Xcode Command Line Tools" \
  xcode-select -p >/dev/null 2>&1 || sudo xcode-select --install

# --- Ricing ---
require_pkgs \
  FelixKratz/formulae/sketchybar \
  FelixKratz/formulae/borders \
  asmvik/formulae/yabai \
  fastfetch \
  yqrashawn/goku/goku \
  cask:karabiner-elements \
  cask:abue-ammar/tinycast/tinycast \
  cask:zen-browser \
  cask:iina \
  cask:pearcleaner \
  cask:font-fira-code-nerd-font \
  cask:font-hack-nerd-font \
  cask:font-jetbrains-mono-nerd-font \
  cask:font-roboto-mono-nerd-font
