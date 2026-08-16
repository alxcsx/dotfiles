#!/usr/bin/env bash

if false; then
  source "../.utils/common_v2.sh"
  source "../.utils/common.sh"
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

step --run-if '$OS = "Darwin"' \
  "Allow emacs through MacOs quarantine"
sudo xattr -r -d com.apple.quarantine /opt/homebrew/opt/emacs-plus@30/Emacs.app 2>/dev/null || true
