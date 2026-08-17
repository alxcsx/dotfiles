#!/usr/bin/env bash
# name:		kitty.install.sh
# desc:		Configure the Kitty terminal emulator and apply the Gruber Darker theme
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

KITTY_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"

step "Create Kitty Config Dir" mkdir -p "$KITTY_DEST"

# Symlink the configurations
link_file "$MODULE_DIR/kitty.conf" "$KITTY_DEST/kitty.conf"
link_file "$MODULE_DIR/theme.conf" "$KITTY_DEST/theme.conf"
link_file "$MODULE_DIR/kitty.app.png" "$KITTY_DEST/kitty.app.png"
link_file "$MODULE_DIR/kitty.app.icns" "$KITTY_DEST/kitty.app.icns"

append_rc_step "kitty" '$(cat << SHELL
alias ssh="kitten ssh"
SHELL
)'
