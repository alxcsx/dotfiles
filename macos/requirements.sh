#!/bin/bash
# name:		macos.requirements.sh
# desc:		requirements for macos module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

assert [ "$OS" = "darwin" ] -- \
         "Not on MACOS" \
         "This Module Only Works on Darwin Machines"

step -I \
     --skip-if 'xcode-select -p >/dev/null 2>&1'\
     "Install Xcode Command Line Tools" \
     sudo xcode-select --install

# --- Ricing ---
require_pkgs \
  FelixKratz/formulae/borders \
  fastfetch \
  yqrashawn/goku/goku \
  cask:nikitabobko/tap/aerospace \
  cask:karabiner-elements \
  cask:sol \
  cask:zen-browser \
  cask:iina \
  cask:pearcleaner \
  cask:font-fira-code-nerd-font \
  cask:font-hack-nerd-font \
  cask:font-jetbrains-mono-nerd-font \
  cask:font-roboto-mono-nerd-font


require_custom -c "aerospace-swipe" -- run_remote_script https://raw.githubusercontent.com/acsandmann/aerospace-swipe/main/install.sh
