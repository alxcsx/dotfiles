#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.utils/common.sh
source "$DOTFILES_DIR/.utils/common.sh"
require_mod "dev"
check_requirements "$SCRIPT_DIR"

EMACS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"

printfln "${BLUE}[i]${NC} Installing Rust LSP Booster..."
# Cargo is provided by mise in your dev module
cargo install emacs-lsp-booster

printfln "${BLUE}[i]${NC} Setting up Emacs configuration..."
mkdir -p "$EMACS_CONFIG_DIR"

if [ -d "$HOME/.emacs.d" ] && [ ! -L "$HOME/.emacs.d" ]; then
  printfln "${RED}[!]${NC} Found legacy ~/.emacs.d. Backing up to ${EMACS_CONFIG_DIR}/.emacs.d.bak..."
  mv "${HOME}/.emacs.d" "${EMACS_CONFIG_DIR}/.emacs.d.bak"
fi

for item in "$SCRIPT_DIR/config/"*; do
  [ -e "$item" ] || continue

  if git check-ignore -q "$item"; then
    continue
  fi

  target=$(basename "$item")
  target_path="$EMACS_CONFIG_DIR/$target"

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    rm -rf "$target_path"
  fi

  ln -s "$item" "$target_path"
done

printfln "${GREEN}[OK]${NC} Symlinked Emacs configuration to $EMACS_CONFIG_DIR"

# 5. Allowing emacs through quarantine
if [ "$(uname)" = "Darwin" ]; then
  printfln "${BLUE}[i]${NC} Bypassing Gatekeeper..."
  sudo xattr -r -d com.apple.quarantine /opt/homebrew/opt/emacs-plus@30/Emacs.app 2>/dev/null || true
  printfln "For better results, also add it as dev tool"
fi
printfln "${GREEN}[OK]${NC} Emacs Daemon is running"

# 6. Final Polish
printfln ""
printfln "${GREEN}[OK]${NC} Emacs module installation complete!"
printfln "${BLUE}[i]${NC} Run 'emacsclient -c' to open Emacs and trigger the Elpaca bootstrap."
