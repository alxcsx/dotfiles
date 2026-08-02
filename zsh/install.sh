#!/bin/bash
# name:		zsh.install.sh
# desc:		Install Zsh configuration and set as default shell
# author:	Alex Candido <github:alxcsx>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../.utils/common.sh"

validate_module_context
check_requirements "$SCRIPT_DIR"

ZSH_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
BACKUP_DIR="$ZSH_DEST/backup"

echo -e "${BLUE}[i]${NC} Starting Zsh configuration..."

# Check if Zsh is installed
if ! command -v zsh >/dev/null 2>&1; then
    echo -e "${RED}[!]${NC} Error: Zsh is not installed on this system. Please install it first."
    exit 1
fi

# 1. Configure global ZDOTDIR
echo ""
echo -e "${GREEN}[-]${NC} Configuring global ZDOTDIR..."

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
    ZSHENV_PATH="/etc/zshenv"
elif [ -d "/etc/zsh" ]; then
    ZSHENV_PATH="/etc/zsh/zshenv"
else
    ZSHENV_PATH="/etc/zshenv"
fi

if ! grep -q "ZDOTDIR=" "$ZSHENV_PATH" 2>/dev/null; then
    echo "  -> Requesting sudo to set global ZDOTDIR in $ZSHENV_PATH..."
    sudo tee -a "$ZSHENV_PATH" >> /dev/null <<- 'SHELL'
    # Custom Zsh directory configuration
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
SHELL
    echo "  -> Global ZDOTDIR configured."
else
    echo "  -> Global ZDOTDIR already configured in $ZSHENV_PATH."
fi

# 2. Create XDG directories
echo ""
echo -e "${GREEN}[-]${NC} Creating XDG directories..."

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

mkdir -p "$ZSH_DEST"
mkdir -p "$XDG_CACHE_HOME/zsh"
mkdir -p "$XDG_STATE_HOME/zsh"
echo "  -> Created directories."

# 3. Create symlinks for config files
echo ""
echo -e "${GREEN}[-]${NC} Creating symlinks..."

ZSH_SRC="$DOTFILES_DIR/zsh"

for file in .zshrc .zshenv .zprofile .zlogin .zlogout; do
    LINK="$ZSH_DEST/$file"
    if [ ! -L "$LINK" ] && [ -f "$ZSH_SRC/$file" ]; then
        ln -sf "$ZSH_SRC/$file" "$LINK"
        echo "  -> Created symlink: $LINK"
    elif [ -L "$LINK" ] && [ "$(readlink "$LINK")" != "$ZSH_SRC/$file" ]; then
        rm -f "$LINK"
        ln -sf "$ZSH_SRC/$file" "$LINK"
        echo "  -> Updated symlink: $LINK"
    fi
done

# 4. Create symlink for modules directory
MODULES_LINK="$ZSH_DEST/modules"
if [ ! -L "$MODULES_LINK" ] && [ -d "$ZSH_SRC/modules" ]; then
    ln -sf "$ZSH_SRC/modules" "$MODULES_LINK"
    echo "  -> Created symlink: $MODULES_LINK"
fi

# 5. Change default shell to Zsh
echo ""
echo -e "${GREEN}[-]${NC} Setting Zsh as default shell..."

CURRENT_SHELL="$SHELL"

ZSH_PATH=$(grep -m 1 -E '/zsh$' /etc/shells)

if [ -z "$ZSH_PATH" ]; then
    echo -e "${RED}[!]${NC} Error: zsh is installed, but no valid path was found in /etc/shells."
    exit 1
fi

if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    echo "  -> Current shell is: $CURRENT_SHELL"
    
    mkdir -p "$BACKUP_DIR"
    echo "$CURRENT_SHELL" > "$BACKUP_DIR/previous_shell.txt"
    echo "  -> Saved previous shell."
    
    echo "  -> Changing default shell to Zsh (requires password)..."
    chsh -s "$ZSH_PATH"
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}[!]${NC} Warning: Failed to change shell. Run: chsh -s $(command -v zsh)"
    else
        echo "  -> Shell changed successfully."
    fi
else
    echo "  -> Zsh is already the default shell."
fi

echo ""
echo "[i] Zsh installation complete!"
