#!/bin/bash
# name:		dev.install.sh
# desc:		Configure base dev environment with mise-en-place
# author:	Alex Candido <github:alxcsx>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../.utils/common.sh"

XDG_ENV_PATH="$SCRIPT_DIR/xdg_env.sh"
source "$XDG_ENV_PATH"

validate_module_context
check_requirements "$SCRIPT_DIR"

# --- Git Interactive Configuration ---
echo -e "\n${BLUE}[-] Checking Git Configuration...${NC}"

# Check and prompt for Git user.name
if [ -z "$(git config --global user.name)" ]; then
    echo -e "${YELLOW}[?] Git user.name is not set.${NC}"
    read -p "  -> Enter your full name for Git: " git_name
    git config --global user.name "$git_name"
    echo -e "  -> ${GREEN}[OK]${NC} Git name set to '$git_name'."
else
    echo -e "  -> ${GREEN}[OK]${NC} Git name is already set ($(git config --global user.name))."
fi

# Check and prompt for Git user.email
if [ -z "$(git config --global user.email)" ]; then
    echo -e "${YELLOW}[?] Git user.email is not set.${NC}"
    read -p "  -> Enter your email for Git: " git_email
    git config --global user.email "$git_email"
    echo -e "  -> ${GREEN}[OK]${NC} Git email set to '$git_email'."
else
    echo -e "  -> ${GREEN}[OK]${NC} Git email is already set ($(git config --global user.email))."
fi

if [ -f "$HOME/.gitconfig" ]; then
	mkdir -p "$HOME/.config/git" && mv "$HOME/.gitconfig" "$HOME/.config/git/config"
fi

# Installing Languages:

mise_install(){
	mise use --global "$1@$2" 	|| { echo -e "${RED}[!]${NC} Failed to install $1"; exit 1; }
}

echo -e "\n${BLUE}[-] Configuring Mise and installing languages...${NC}"
export PATH="$HOME/.local/bin:$PATH"

if command -v mise >/dev/null 2>&1; then
	echo -e "  -> Installing global environments..."

# Python
	mise_install python latest
	mise_install uv latest
	mise_install ruff latest
# DOTNET
	mise_install dotnet 10
# JVM
	mise_install java lts
# JS
	mise_install node lts
	mise_install deno latest
	mise_install pnpm latest
# BEAM
	mise_install erlang 29.0.4
	mise_install elixir latest
# OTHERS
	mise_install rust latest
	mise_install just latest

	echo -e "  -> ${GREEN}[OK]${NC} Languages successfully installed and set as global defaults."
else
	echo -e "  -> ${RED}[!]${NC} Mise command not found. Skipping language installation."
fi

# Configure Node
mise exec node -- corepack enable

# Inject Mise and direnv into Shell:
append_rc "dev" "$(cat << SHELL
$(cat "$XDG_ENV_PATH")

# Activate Mise
eval "\$(mise activate \$(basename \$SHELL))"
# Activate Direnv
eval "\$(direnv hook \$(basename \$SHELL))"

alias docker="podman"
SHELL
)"