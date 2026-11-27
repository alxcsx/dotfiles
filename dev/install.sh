#!/bin/bash
# name:		dev.install.sh
# desc:		Configure base dev environment with mise-en-place
# author:	Alex Candido <github:alxcsx>

if false; then
	source "../dot.sh"
fi

command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"

# Helpers:
mise_install_step() {
	step "install $1@$2 through mise" mise use --global "$1@$2" || {
		printfln "${RED}[!]${NC} Failed to install $1"
		return 1
	}
}

dotnet_tool_step() {
	local tool="$1"
	local bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
	local tools_dir="${DOTNET_CLI_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/dotnet}/.dotnet/tools"

	if command -v "$tool" >/dev/null 2>&1; then
		step "Update $tool via dotnet tool" \
			bash -c 'dotnet tool update -g "$1" || echo "Warning: $1 update failed; keeping installed version" >&2' _ "$tool"
	else
		step "Install $tool via dotnet tool" \
			dotnet tool install -g "$tool" || return 1
	fi

	if [ -x "$tools_dir/$tool" ]; then
		mkdir -p "$bin_dir"
		ln -sf "$tools_dir/$tool" "$bin_dir/$tool"
	fi
}

install_omnisharp() {
	local bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
	local dest_dir="${XDG_DATA_HOME:-$HOME/.local/share}/omnisharp"

	local os_target arch_target
	case "${OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}" in
	linux) os_target="linux" ;;
	darwin) os_target="osx" ;;
	*)
		printfln "${RED}[!]${NC} Unsupported OS for OmniSharp"
		return 1
		;;
	esac

	case "$(uname -m)" in
	x86_64 | amd64) arch_target="x64" ;;
	aarch64 | arm64) arch_target="arm64" ;;
	*)
		printfln "${RED}[!]${NC} Unsupported architecture for OmniSharp"
		return 1
		;;
	esac

	local url="https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-${os_target}-${arch_target}.tar.gz"
	mkdir -p "$dest_dir" "$bin_dir" || return 1
	curl -sSL "$url" | tar -xz -C "$dest_dir" || return 1
	chmod +x "$dest_dir/OmniSharp" || return 1

	local omnisharp_bin="$dest_dir/OmniSharp"
	if [ -x "$omnisharp_bin" ]; then
		mkdir -p "$bin_dir"
		ln -sf "$omnisharp_bin" "$bin_dir/omnisharp"
		ln -sf "$omnisharp_bin" "$bin_dir/OmniSharp"
	fi
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
dotnet_tool_step csharp-ls
step "Install or update OmniSharp language server" install_omnisharp
dotnet_tool_step fsautocomplete
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

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
step "Create elixir_ls config dir" mkdir -p "$CONFIG_DIR/elixir_ls"
link_file "$MODULE_DIR/elixir_ls/setup.sh" "$CONFIG_DIR/elixir_ls/setup.sh"
step "Run elixir_ls setup hook" "$CONFIG_DIR/elixir_ls/setup.sh"

if [[ "$OS" == "linux" ]]; then
	step --skip-if '[ -d /home/runner/work/elixir ]' \
		"Create Elixir runner work directory" \
		sudo mkdir -p /home/runner/work/elixir

	step --skip-if '[ -L /home/runner/work/elixir/elixir ] && [ "$(readlink /home/runner/work/elixir/elixir 2>/dev/null)" = "'"$HOME/.local/share/mise/current-elixir"'" ]' \
		"Symlink Elixir runner path for elixir-ls" \
		sudo ln -sfn "$HOME/.local/share/mise/current-elixir" /home/runner/work/elixir/elixir
fi

# OTHERS
mise_install_step rust latest
mise_install_step just latest
mise_install_step tilt latest
# KUBERNETES
mise_install_step kubectl latest
mise_install_step minikube latest
mise_install_step kustomize latest
# LUA
mise_install_step lua latest
mise_install_step lua-language-server latest
# SHELL
mise_install_step shellcheck latest
mise_install_step shfmt latest

if [[ "$DISTRO" == "macos" ]]; then
	if ! podman machine list | grep -q "podman-machine-default"; then
		step "Init Podman Machine" mise exec podman -- podman machine init
	fi
else
	step "Enable Podman Socket" systemctl --user enable --now podman.socket
fi

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
