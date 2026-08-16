#!/bin/bash
# name:		dev.requirements.sh
# desc:		requirements for dev module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../.utils/packages_v2.sh"
fi

if [[ "$DISTRO" == "macos" ]]; then
  printfln "${GREEN}[*]${NC} Tapping emacs-plus for macOS..."
  brew tap d12frosted/emacs-plus
  brew trust d12frosted/emacs-plus
fi

require_pkgs \
  "linux:emacs" \
  "pinentry" \
  "jetbrains-mono" \
  "victor-mono" \
  "symbols-nerd-font"

require_custom \
  -o "macos" \
  -c "emacs" -- \
  brew install emacs-plus --with-dbus --with-mailutils --with-xwidgets
