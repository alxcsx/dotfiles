#!/bin/bash
# name:		zsh.uninstall.sh
# desc:		Remove Zsh configuration and restore previous shell
# author:	Alex Candido <github:alxcsx>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../.utils/common.sh"

validate_module_context

ZSH_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
BACKUP_DIR="$ZSH_DEST/backup"

echo "[i] Starting Zsh uninstallation..."

# 1. Remove symlinks
echo ""
echo "[-] Removing symlinks..."

for file in .zshrc .zshenv .zprofile .zlogin .zlogout; do
    LINK="$ZSH_DEST/$file"
    if [ -L "$LINK" ]; then
        rm -f "$LINK"
        echo "  -> Removed: $LINK"
    fi
done

MODULES_LINK="$ZSH_DEST/modules"
if [ -L "$MODULES_LINK" ]; then
    rm -rf "$MODULES_LINK"
    echo "  -> Removed: $MODULES_LINK"
fi

# 2. Restore previous shell
echo ""
echo "[-] Restoring previous shell..."

PREVIOUS_SHELL_FILE="$BACKUP_DIR/previous_shell.txt"
if [ -f "$PREVIOUS_SHELL_FILE" ]; then
    PREVIOUS_SHELL="$(cat "$PREVIOUS_SHELL_FILE")"
    echo "  -> Previous shell was: $PREVIOUS_SHELL"

    if [ "$PREVIOUS_SHELL" != "$SHELL" ]; then
        echo "  -> Changing shell back to: $PREVIOUS_SHELL"
        chsh -s "$PREVIOUS_SHELL"
        if [ $? -ne 0 ]; then
            echo "[!] Warning: Failed to change shell. Manual intervention needed."
        else
            echo "  -> Shell restored."
        fi
    else
        echo "  -> Shell is already: $PREVIOUS_SHELL"
    fi
else
    echo "[!] Warning: No backup of previous shell found. Manual restoration needed."
fi

# 3. Remove Zsh directories
echo ""
echo "[-] Removing Zsh directories..."

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

for dir in "$ZSH_DEST" "$BACKUP_DIR" "$XDG_CACHE_HOME/zsh" "$XDG_STATE_HOME/zsh"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "  -> Removed: $dir"
    fi
done

# 4. Remove global ZDOTDIR configuration
echo ""
echo "[-] Removing global ZDOTDIR configuration..."

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
    ZSHENV_PATH="/etc/zshenv"
elif [ -d "/etc/zsh" ]; then
    ZSHENV_PATH="/etc/zsh/zshenv"
else
    ZSHENV_PATH="/etc/zshenv"
fi

if grep -q "ZDOTDIR=" "$ZSHENV_PATH" 2>/dev/null; then
    echo "  -> Found ZDOTDIR in $ZSHENV_PATH"
    echo "[!] Manual cleanup required: Edit $ZSHENV_PATH to remove ZDOTDIR line"
else
    echo "  -> No global ZDOTDIR configuration found."
fi

echo ""
echo "[i] Zsh uninstallation complete!"
