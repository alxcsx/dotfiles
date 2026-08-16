#!/bin/bash
# name:		zsh.install.sh
# desc:		Install Zsh configuration and set as default shell
# author:	Alex Candido <github:alxcsx>

# --- ShellCheck Context
if false; then # --- ignore at runtime
  # shellcheck source=../.utils/common.sh
  source "../.utils/common.sh"
  # shellcheck source=../.utils/common_v2.sh
  source "../.utils/common_v2.sh"
  # shellcheck source=../dot.sh
  source "../dot.sh"
fi

validate_module_context

ZSH_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
ZSH_SRC="$DOTFILES_DIR/zsh"
MODULES_LINK="$ZSH_DEST/modules"

ZSHENV_PATH="/etc/zshenv"
[[ "$OS" != "Darwin" && -d "/etc/zsh" ]] && ZSHENV_PATH="/etc/zsh/zshenv"

ZSH_PATH=$(grep -m 1 -E '/zsh$' /etc/shells)
assert [ -n "$ZSH_PATH" ] -- "ZSH path not found in /etc/shells" "Ensure ZSH is installed"

step \
  --skip-if 'grep -q "export ZDOTDIR=" /etc/zshenv && [[ "$ZDOTDIR" == "$ZSH_DEST" ]]' \
  -b \
  "Configure global zsh to use XDG standard" \
  sudo tee -a "$ZSHENV_PATH" >>/dev/null <<-SHELL
		    # Custom Zsh directory configuration
		    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
		    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
	SHELL

step "Create XDG directories" mkdir -p "$ZSH_DEST" "$XDG_CACHE_HOME/zsh" "$XDG_STATE_HOME/zsh"

for file in .zshrc .zshenv .zprofile .zlogin .zlogout; do
  SOURCE="$ZSH_SRC/$file"
  LINK="$ZSH_DEST/$file"
  if [ ! -f "$SOURCE" ]; then
    continue
  fi
  link_file "$SOURCE" "$LINK"
done

link_file -m "Symlink Custom Modules Dir" "$ZSH_SRC/modules" "$MODULES_LINK"

step --skip-if '[ "$SHELL" == "$ZSH_PATH" ]' \
  -b \
  "Set ZSH as default shell" \
  sudo chsh -s "$ZSH_PATH"
