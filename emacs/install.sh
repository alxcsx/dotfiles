#!/usr/bin/env bash

if false; then
  source "../dot.sh"
fi

EMACS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"

# Cargo is provided by mise in your dev module
step "Install Rust LSP Booster" \
  cargo install emacs-lsp-booster

step "Set Emacs config dir" \
  mkdir -p "$EMACS_CONFIG_DIR"

step --run-if '[ -d "$HOME/.emacs.d" ] && [ ! -L "$HOME/.emacs.d" ]' -b \
  "Clear Existing ~/.emacs.d" \
  rm -rf "${HOME}/.emacs.d"

link_dir_content -b "$MODULE_DIR/config" "$EMACS_CONFIG_DIR"

EMACS_APP="$(brew --prefix 2>/dev/null)/opt/emacs-plus/Emacs.app"
step --run-if '[[ "$OS" == "darwin" ]] && [ -d "'"$EMACS_APP"'" ] && xattr -p com.apple.quarantine "'"$EMACS_APP"'" >/dev/null 2>&1' \
  "Allow emacs through MacOs quarantine" \
sudo xattr -r -d com.apple.quarantine "$EMACS_APP"
