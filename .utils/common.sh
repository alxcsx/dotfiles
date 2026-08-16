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

is_mod_installed() {
  local target_mod="$1"

  if grep -q "^${target_mod}|installed|" "$STATE_FILE" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Detect the target RC file based on current shell
get_rc_file() {
  local shell_name="$(basename "$SHELL")"
  local rc_file=""

  case "$shell_name" in
  bash)
    if [[ "$OS" == "macos" ]]; then
      rc_file="$HOME/.bash_profile"
    else
      rc_file="$HOME/.bashrc"
    fi
    ;;
  zsh)
    if is_mod_installed "zsh"; then
      rc_file="${ZDOTDIR:-$HOME/.config/zsh}/.zshrc.local"
    else
      rc_file="${ZDOTDIR:-$HOME}/.zshrc"
    fi
    ;;
  fish)
    rc_file="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
    ;;
  *)
    rc_file="$HOME/.bashrc"
    ;;
  esac
  echo "$rc_file"
}

_append_rc_module() {
  local module_name="$1"
  local content="$2"
  local rc_file="$3"
  local ext="$4"
  local shebang="$5"

  if [ -z "$module_name" ] || [ -z "$content" ]; then
    printfln "${RED}[!] Error: append function requires module name and content${NC}"
    return 1
  fi

  local dotsh_dir="$(dirname "$rc_file")/.dotsh"
  local module_file="$dotsh_dir/${module_name}.${ext}"

  local source_line="source \"$module_file\""
  local marker="# >>> dotfiles ${module_name} module >>>"
  local marker_end="# <<< dotfiles ${module_name} module <<<"

  # Create parent directories and RC file if they don't exist
  if [ ! -f "$rc_file" ]; then
    mkdir -p "$(dirname "$rc_file")"
    touch "$rc_file"
    printfln "${BLUE}[i]${NC} Created RC file: $rc_file"
  fi

  # If the source line is not already present, append it.
  if ! grep -q "$marker" "$rc_file"; then
    \cat >>"$rc_file" <<SHELL
$marker
# Injected by dotfiles '${module_name}' module
$source_line
$marker_end
SHELL
  else
    printfln "${YELLOW}[!]${NC} RC Append '$module_name' already configured in $rc_file. Skipping."
  fi

  mkdir -p "$dotsh_dir"

  # Overwrite the module file
  \cat >"$module_file" <<-SHELL
		#!/usr/bin/env $shebang
		$marker
		# Injected by dotfiles '${module_name}' module
		$content
		$marker_end
	SHELL

  chmod +x "$module_file"
  printfln "${GREEN}[OK]${NC} Appended ${module_name} configuration to $rc_file"
  return 0
}

append_rc_step() {
  local message=""
  if [ "$1" == "-m" ]; then
    message="$2"
    shift 2
  fi

  [ -z "$message" ] && message="Appending Module $1 to RC file"
  step "$message" append_rc "$@"
}

# --- Bash/Zsh Wrapper ---
append_rc() {
  local shell_name="$(basename "$SHELL")"
  [ "$shell_name" = "fish" ] && return 0

  local rc_file="$(get_rc_file)"
  _append_rc_module "$1" "$2" "$rc_file" "sh" "bash"
}

# --- Fish Wrapper ---
append_fishrc() {
  local shell_name="$(basename "$SHELL")"
  [ "$shell_name" != "fish" ] && return 0

  local rc_file="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
  _append_rc_module "$1" "$2" "$rc_file" "fish" "fish"
}
