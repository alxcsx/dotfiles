#!/bin/sh
# name:		common.sh
# desc:		Shared helper functions for dotfiles management
# author:	Alex Candido <github:alxcsx>
set -e
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

# HELPERS
install_package() {
    local pkg="$1"
    shift
    
    local is_cask=false
    local is_aur=false
    
    for flag in "$@"; do
        [[ "$flag" == "--cask" ]] && is_cask=true
        [[ "$flag" == "--aur" ]] && is_aur=true
    done
    
    echo "  > Installing $pkg via package manager..."
    case "$DISTRO" in
        macos) if $is_cask; then brew install --cask "$pkg"; else brew install "$pkg"; fi ;;
        ubuntu|debian) sudo apt-get update -qq && sudo apt-get install -y "$pkg" ;;
        arch)
            if $is_aur; then
                if command -v yay >/dev/null 2>&1; then yay -S --noconfirm "$pkg"
            else echo "  ! 'yay' is required to install $pkg but is not installed."; exit 1; fi
            else
                sudo pacman -S --noconfirm "$pkg"
        fi ;;
        fedora) sudo dnf install -y "$pkg" ;;
        *) echo "  ! Unsupported distribution for automatic install: $DISTRO"; exit 1 ;;;
    esac
}

# DSL

sanitize() { echo "${1//-/_}"; }
set_cmd() {
    local pkg=$(sanitize "$1")
    eval "DEFAULT_CMD_${pkg}='$2'"
}
override_pkg() {
    local pkg=$(sanitize "$1")
    eval "OVERRIDE_PKG_${pkg}_$2='$3'"
}
override_cmd() {
    local pkg=$(sanitize "$1")
    eval "OVERRIDE_CMD_${pkg}_$2='$3'"
}
custom_install() {
    local pkg=$(sanitize "$1")
    eval "CUSTOM_INSTALL_${pkg}_$2='$3'"
}

require() {
    local base_pkg="$1"
    shift
    local flags=("$@")
    local safe_pkg=$(sanitize "$base_pkg")
    
    local is_cask=false
    local is_aur=false
    for flag in "${flags[@]}"; do
        [[ "$flag" == "--cask" ]] && is_cask=true
        [[ "$flag" == "--aur" ]] && is_aur=true
    done
    
    local target_pkg="$base_pkg"
    local pkg_var="OVERRIDE_PKG_${safe_pkg}_${DISTRO}"
    [[ -n "${!pkg_var}" ]] && target_pkg="${!pkg_var}"
    
    local is_installed=false
    
    local custom_var="CUSTOM_INSTALL_${safe_pkg}_${DISTRO}"
    local custom_all_var="CUSTOM_INSTALL_${safe_pkg}_all"
    
    if [[ -n "${!custom_var}" ]] || [[ -n "${!custom_all_var}" ]]; then
        local target_cmd="$target_pkg"
        local default_cmd_var="DEFAULT_CMD_${safe_pkg}"
        [[ -n "${!default_cmd_var}" ]] && target_cmd="${!default_cmd_var}"
        
        local cmd_var="OVERRIDE_CMD_${safe_pkg}_${DISTRO}"
        [[ -n "${!cmd_var}" ]] && target_cmd="${!cmd_var}"
        
        if command -v "$target_cmd" >/dev/null 2>&1; then
            echo "[OK] $base_pkg is already installed (found command: $target_cmd)."
            return 0
        fi
    else
        case "$DISTRO" in
            macos)
                if $is_cask; then
                    brew list --cask "$target_pkg" >/dev/null 2>&1 && is_installed=true
                else
                    brew list --formula "$target_pkg" >/dev/null 2>&1 && is_installed=true
                fi
            ;;
            ubuntu|debian)
                dpkg-query -W -f='${Status}' "$target_pkg" 2>/dev/null | grep -q "ok installed" && is_installed=true
            ;;
            arch)
                if $is_aur && command -v yay >/dev/null 2>&1; then
                    yay -Q "$target_pkg" >/dev/null 2>&1 && is_installed=true
                else
                    pacman -Q "$target_pkg" >/dev/null 2>&1 && is_installed=true
                fi
            ;;
            fedora)
                rpm -q "$target_pkg" >/dev/null 2>&1 && is_installed=true
            ;;
        esac
        
        if $is_installed; then
            echo "[OK] $base_pkg is already installed (verified via package manager)."
            return 0
        fi
    fi
    
    if $is_installed; then
        echo "[OK] $base_pkg is already installed (verified via package manager)."
        return 0
    fi
    
    echo "[INSTALL] Missing $base_pkg. Installing..."
    
    # 3. Execute installation
    if [[ -n "${!custom_var}" ]]; then
        echo "  > Running distro-specific custom installer..."
        eval "${!custom_var}"
        elif [[ -n "${!custom_all_var}" ]]; then
        echo "  > Running global custom installer..."
        eval "${!custom_all_var}"
    else
        install_package "$target_pkg" "${flags[@]}"
    fi
}