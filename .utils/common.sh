#!/bin/bash
# name:		common.sh
# desc:		Shared helper functions for dotfiles management
# author:	Alex Candido <github:alxcsx>

# Initialize STATE_FILE if not set (must be at top level before any functions)
if [ -z "$STATE_FILE" ]; then
    STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/state.txt"
    mkdir -p "$(dirname "$STATE_FILE")"
    [ ! -f "$STATE_FILE" ] && touch "$STATE_FILE"
fi

# Get short git commit hash
get_git_hash() {
    git rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

validate_module_context() {
    if [ -z "$DOTFILES_DIR" ]; then
        echo "[!] Error: This script must be called via dot.sh"
        exit 1
    fi
}

# Update state file: module|status|version
update_state() {
    local module=$1
    local status=$2
    local version=$3
    # Remove old entry if exists, then append new one
    grep -v "^${module}|" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null
    echo "${module}|${status}|${version}" >> "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Remove module from state file
remove_state() {
    local module=$1
    grep -v "^${module}|" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null
    mv "$STATE_FILE.tmp" "$STATE_FILE"
}