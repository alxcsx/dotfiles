#!/bin/zsh
ZPLUGINDIR="${ZDOTDIR:-$HOME/.config/zsh}/plugins"

_zplugin_load(){
	local plugin_path="$ZPLUGINDIR/${2}"
	if [[ ! -d "$plugin_path" ]]; then
		mkdir -p "$ZPLUGINDIR"
		echo "Installing plugin $2..."
		git clone --depth 1 "https://github.com/${1}/${2}.git" "$plugin_path" \
			|| { echo "ERROR: Failed to clone plugin $2" >&2; return 1; }
	fi
	source "${plugin_path}/${2}.plugin.zsh"
}

zplugin-update(){
	local dir
	for dir in "${ZPLUGINDIR}"/*/; do
		if [[ -d "$dir" ]]; then
			echo "Updating plugin $(basename "$dir")..."
			git -C "$dir" pull --ff-only
		fi
	done
}

_zplugin_load "zsh-users" "zsh-autosuggestions"
_zplugin_load "zsh-users" "zsh-history-substring-search"
_zplugin_load "zdharma-continuum" "fast-syntax-highlighting"