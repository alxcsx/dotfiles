#!/bin/bash
# name:		dev.requirements.sh
# desc:		requirements for dev module
# author:	Alex Candido <github:alxcsx>

if false; then
	source "../dot.sh"
fi

source "$MODULE_DIR/xdg_env.sh"

# --- Tools ---
require_pkgs \
	git \
	podman \
	podman-compose \
	direnv \
	fd \
	ripgrep \
	openssl \
	pkgconf \
	xh \
	bash-language-server \
	wxwidgets \
	libffi \
	unixodbc \
	"linux:inotify-tools"

install_or_update_mise() {
	if command -v mise >/dev/null 2>&1; then
		if command -v pacman >/dev/null 2>&1 && pacman -Qq mise >/dev/null 2>&1; then
			return 0
		fi
		mise self-update -y
	else
		run_remote_script https://mise.run
	fi
}

step "Install or update mise" install_or_update_mise
