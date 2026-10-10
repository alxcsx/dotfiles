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

# Unity wrapper script
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

step "Set local bin dir" \
  mkdir -p "$BIN_DIR"

step --skip-if '[ -x "$MODULE_DIR/bin/unity-emacs" ]' \
  "Make unity-emacs executable" \
  chmod +x "$MODULE_DIR/bin/unity-emacs"

link_file "$MODULE_DIR/bin/unity-emacs" "$BIN_DIR/unity-emacs"

# Directory handler (Dired/Dirvish) - Linux FreeDesktop / XDG
if [[ "$OS" == "linux" ]]; then
  step --skip-if '[ -x "$MODULE_DIR/bin/emacs-dired" ]' \
    "Make emacs-dired executable" \
    chmod +x "$MODULE_DIR/bin/emacs-dired"

  link_file "$MODULE_DIR/bin/emacs-dired" "$BIN_DIR/emacs-dired"

  APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

  step "Set applications dir" \
    mkdir -p "$APPS_DIR"

  link_file "$MODULE_DIR/applications/emacs-dired.desktop" "$APPS_DIR/emacs-dired.desktop"

  step --run-if 'command -v update-desktop-database >/dev/null 2>&1' \
    "Update desktop database" \
    update-desktop-database "$APPS_DIR"

  step --run-if 'command -v xdg-mime >/dev/null 2>&1' \
    --skip-if '[ "$(xdg-mime query default inode/directory 2>/dev/null)" = "emacs-dired.desktop" ]' \
    "Set Emacs Dired as default directory handler" \
    xdg-mime default emacs-dired.desktop inode/directory
fi

EMACS_APP="$(brew --prefix 2>/dev/null)/opt/emacs-plus/Emacs.app"
step --run-if '[[ "$OS" == "darwin" ]] && [ -d "'"$EMACS_APP"'" ] && xattr -p com.apple.quarantine "'"$EMACS_APP"'" >/dev/null 2>&1' \
  "Allow emacs through MacOs quarantine" \
sudo xattr -r -d com.apple.quarantine "$EMACS_APP"

