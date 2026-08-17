#!/bin/bash
# name:	common.sh
# desc:		Shared helper functions for dotfiles management
# author:	Alex Candido <github:alxcsx>

# Initialize STATE_FILE if not set (must be at top level before any functions)
if [ -z "$STATE_FILE" ]; then
  STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/state.txt"
  mkdir -p "$(dirname "$STATE_FILE")"
  [ ! -f "$STATE_FILE" ] && touch "$STATE_FILE"
fi

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
DISTRO=""
if [[ "$OS" == "linux" ]]; then
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    DISTRO="$ID"
  fi
elif [[ "$OS" == "darwin" ]]; then
  DISTRO="macos"
fi

if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=''
  NC=''
fi

_printfln() {
  local format="$1"
  shift
  printf "${format}\n" "$@"
}

# Get short git commit hash
get_git_hash() {
  git rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

validate_module_context() {
  if [ -z "$DOTFILES_DIR" ]; then
    printfln "${RED}[!] Error: This script must be called via dot.sh${NC}"
    exit 1
  fi
}

# Update state file: module|status|version
update_state() {
  local module=$1
  local status=$2
  local version=$3
  # Remove old entry if exists, then append new one
  grep -v "^${module}|" "$STATE_FILE" >"$STATE_FILE.tmp" 2>/dev/null
  echo "${module}|${status}|${version}" >>"$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Remove module from state file
remove_state() {
  local module=$1
  grep -v "^${module}|" "$STATE_FILE" >"$STATE_FILE.tmp" 2>/dev/null
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

check_requirements() {
  local module_dir="$1"
  local req_file="$module_dir/requirements.sh"

  if [ -f "$req_file" ]; then
    echo ""
    printfln "${BLUE}[i]${NC} Checking system requirements for module..."
    if ! source "$req_file"; then
      printfln "${RED}[!] Please fix missing dependencies before proceeding.${NC}"
      exit 1
    fi
  fi
}

require_mod() {
  local required_mod

  # Loop through all arguments passed to the function
  for required_mod in "$@"; do
    if grep -q "^${required_mod}|installed|" "$STATE_FILE" 2>/dev/null; then
      # Use GREEN for success
      printfln "  -> ${GREEN}[OK]${NC} Module '${BOLD}$required_mod${NC}' is installed."
    else
      # Use YELLOW for warnings
      printfln "  -> ${YELLOW}[!] Warning:${NC} Recommended module '${BOLD}$required_mod${NC}' is not installed."
      printfln "         Consider running: ./dot.sh install $required_mod"
    fi
  done
}
