#!/bin/bash
# name:		dev.install.sh
# desc:		Configure base dev environment with mise-en-place
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

# Helpers:
mise_install_step() {
  step "install $1@$2 through mise" mise use --global "$1@$2" || {
    printfln "${RED}[!]${NC} Failed to install $1"
    return 1
  }
}

step --run-if '[ -z "$(git config --global user.name)" ]' -I \
  "Set default Git name" \
  bash -c 'read -r -p "  -> Enter your full name for Git: " git_name && git config --global user.name "$git_name"'

step --run-if '[ -z "$(git config --global user.email)" ]' -I \
  "Set global Git email" \
  bash -c 'read -r -p "  -> Enter your email for Git: " git_email && git config --global user.email "$git_email"'

step --run-if '[ -f "$HOME/.gitconfig" ]' \
  "Move Existing Git Config to $HOME/.config/git" \
  bash -c 'mkdir -p "$HOME/.config/git" && mv "$HOME/.gitconfig" "$HOME/.config/git/config"'

# Python
mise_install_step python latest
mise_install_step uv latest
mise_install_step ruff latest
# DOTNET
mise_install_step dotnet 10
# JVM
mise_install_step java lts
# JS
mise_install_step node lts
mise_install_step deno latest
mise_install_step pnpm latest
# BEAM
mise_install_step erlang 29.0.4
mise_install_step elixir latest
mise_install_step elixir-ls latest
# OTHERS
mise_install_step rust latest
mise_install_step just latest
# LUA
mise_install_step lua latest
mise_install_step lua-language-server latest
# SHELL
mise_install_step shellcheck latest
mise_install_step shfmt latest

# Configure Node
step "Enable CorePack for node" mise exec node -- corepack enable

# Inject Mise and direnv into Shell:
append_rc_step "dev" "$(
  cat <<SHELL
$(cat "$MODULE_DIR/xdg_env.sh")

# Activate Mise
eval "\$(mise activate \$(basename \$SHELL))"
# Activate Direnv
eval "\$(direnv hook \$(basename \$SHELL))"

alias docker="podman"
SHELL
)"
