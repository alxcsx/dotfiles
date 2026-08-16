#!/bin/bash
# name:		packages.sh
# desc:		Shared DSL for managing package installation
# author:	Alex Candido <github:alxcsx>

# META
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

# HELPERS
printfln() {
  local format="$1"
  shift
  printf "${format}\n" "$@"
}

has_flag() {
  local search="$1"
  shift
  for arg in "$@"; do
    [[ "$arg" == "$search" ]] && return 0
  done
  return 1
}

value_or_default() {
  local var_name="$1"
  local default_val="$2"
  [[ -n "${!var_name}" ]] && echo "${!var_name}" || echo "$default_val"
}

sanitize() { printf '%s' "$1" | sed 's/[^a-zA-Z0-9_]/_/g'; }

install_package() {
  local pkg="$1"
  shift
  local flags=("$@")
  printfln "  ${BOLD}${BLUE}> Installing $pkg via package manager...${NC}"
  case "$DISTRO" in
  macos)
    local type="--formula"
    has_flag "--cask" "${flags[@]}" && type="--cask"
    brew install $type $pkg
    ;;
  ubuntu | debian)
    sudo apt-get update -qq &&
      sudo apt-get install -y "$pkg"
    ;;
  arch)
    if has_flag "--aur" "${flags[@]}"; then
      if command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm "$pkg"
      else
        printfln "${RED}[!] 'yay' is required to install $pkg but is not installed.${NC}"
        exit 1
      fi
    else
      sudo pacman -S --noconfirm "$pkg"
    fi
    ;;
  fedora)
    sudo dnf install -y "$pkg"
    ;;
  *)
    printfln "${RED}[!] Unsupported distribution for automatic install: $DISTRO ${NC}"
    exit 1
    ;;
  esac
}

# DSL
# e.g. override_pkg "fd" "ubuntu" "fd-find"
override_pkg() {
  local pkg=$(sanitize "$1")
  eval "OVERRIDE_PKG_${pkg}_$2='$3'"
}

# used for custom installation only (since the package manager deals with normal packages):
# when the installed command is different from the package name
# (e.g the package is called neovim but the command is nvim)
custom_cmd() {
  local pkg=$(sanitize "$1")
  eval "OVERRIDE_CMD_${pkg}_$2='$3'"
}

#e.g. custom_install "mise" "all" "curl https://mise.run | sh"
custom_install() {
  local pkg=$(sanitize "$1")
  eval "CUSTOM_INSTALL_${pkg}_$2='$3'"
}

get_custom_install() {
  local pkg=$(sanitize "$1")
  local distro="$2"
  local var_name="CUSTOM_INSTALL_${pkg}_${distro}"
  echo "${!var_name}"
}

is_installed() {
  local base_pkg="$1"
  shift
  local flags=("$@")
  local safe_pkg=$(sanitize "$target_pkg")
  local target_pkg="$(value_or_default "OVERRIDE_PKG_${safe_pkg}_${DISTRO}" "$base_pkg")"

  local custom_installer=$(get_custom_install "$safe_pkg" "$DISTRO")
  local global_custom_installer=$(get_custom_install "$safe_pkg" "all")
  if [[ -n "$custom_installer" || -n "$global_custom_installer" ]]; then
    local target_cmd=$(value_or_default "OVERRIDE_CMD_${safe_pkg}_${DISTRO}" "$target_pkg")

    if command -v "$target_cmd" >/dev/null 2>&1; then
      printfln "${GREEN}[OK]${NC} $target_pkg is already installed (found command: $target_cmd)."
      return 0
    else
      return 1
    fi
  else
    case "$DISTRO" in
    macos)
      local type="--formula"
      has_flag "--cask" "${flags[@]}" && type="--cask"
      brew list "$type" "$target_pkg" >/dev/null 2>&1 || return 1
      ;;
    ubuntu | debian)
      dpkg-query -W -f='${Status}' "$target_pkg" 2>/dev/null |
        grep -q "ok installed" || return 1
      ;;
    arch)
      local pm="pacman"
      has_flag "--aur" "${flags[@]}" && command -v yay >/dev/null 2>&1 && pm="yay"
      $pm -Q "$target_pkg" >/dev/null 2>&1 || return 1
      ;;
    fedora)
      rpm -q "$target_pkg" >/dev/null 2>&1 || return 1
      ;;
    *)
      return 1
      ;;
    esac
  fi
}

require() {
  local base_pkg="$1"
  shift
  local flags=("$@")
  local safe_pkg=$(sanitize "$base_pkg")
  local target_pkg="$(value_or_default "OVERRIDE_PKG_${safe_pkg}_${DISTRO}" "$base_pkg")"

  if is_installed "$base_pkg" "${flags[@]}"; then
    printfln "${GREEN}[OK]${NC} $target_pkg is already installed (verified via package manager)."
    return 0
  fi

  printfln "${BLUE}[INSTALL]${NC} Missing $target_pkg. Installing..."

  local custom_installer=$(get_custom_install "$safe_pkg" "$DISTRO")
  local global_custom_installer=$(get_custom_install "$safe_pkg" "all")
  # 3. Execute installation
  if [[ -n "$custom_installer" ]]; then
    printfln "${BOLD} > Running distro-specific custom installer...${NC}"
    eval "$custom_installer"
  elif [[ -n "$global_custom_installer" ]]; then
    printfln "${BOLD}  > Running global custom installer...${NC}"
    eval "$global_custom_installer"
  else
    install_package "$target_pkg" "${flags[@]}"
  fi
}
