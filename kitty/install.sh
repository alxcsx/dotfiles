#!/usr/bin/env bash
# name:		kitty.install.sh
# desc:		Configure the Kitty terminal emulator and apply the Gruber Darker theme
# author:	Alex Candido <github:alxcsx>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/.utils/common.sh"

validate_module_context
check_requirements "$SCRIPT_DIR"

echo -e "${BLUE}[i] Configuring Kitty...${NC}"

KITTY_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
mkdir -p "$KITTY_DEST"

# Symlink the configurations
ln -sf "$SCRIPT_DIR/kitty.conf" "$KITTY_DEST/kitty.conf"
ln -sf "$SCRIPT_DIR/theme.conf" "$KITTY_DEST/theme.conf"
ln -sf "$SCRIPT_DIR/kitty.app.png" "$KITTY_DEST/kitty.app.png"
ln -sf "$SCRIPT_DIR/kitty.app.icns" "$KITTY_DEST/kitty.app.icns"


echo -e "${GREEN}[OK] Kitty configured successfully!${NC}"

append_rc "kitty" '$(cat << SHELL
alias ssh="kitten ssh"
SHELL
)'