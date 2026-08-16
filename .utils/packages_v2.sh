#!/usr/bin/env bash
# .utils/packages.sh
# Declarative, cross-platform package management engine.

# --- ShellCheck Context
if false; then
  source "../.utils/common.sh"
  source "../.utils/common_v2.sh"
fi
# -----------------------------------------------

_translate_pkg() {
  local pkg="$1"
  local map_file="$DOTFILES_DIR/.utils/pkg_alt.conf"

  if [[ -f "$map_file" ]]; then
    local match
    match=$(grep "^$DISTRO $pkg " "$map_file" | awk '{print $3}')

    if [[ -n "$match" ]]; then
      echo "$match"
      return 0
    fi
  fi
  echo "$pkg"
}

_check_macos() {
  if [[ "$1" == cask:* ]]; then
    brew ls --cask "${1#cask:}" &>/dev/null
  else
    brew ls --formula "$1" &>/dev/null
  fi
}

_check_arch() {
  pacman -Qq "$1" &>/dev/null
}

_check_ubuntu() {
  dpkg -l "$1" &>/dev/null
}

_install_macos() {
  local formulas=() casks=()
  for p in "$@"; do
    if [[ "$p" == cask:* ]]; then
      casks+=("${p#cask:}")
    else
      formulas+=("$p")
    fi
  done

  [[ ${#formulas[@]} -gt 0 ]] && brew install "${formulas[@]}"
  [[ ${#casks[@]} -gt 0 ]] && brew install --cask "${casks[@]}"
}

_install_arch() {
  local native=() aur=()
  for p in "$@"; do
    if [[ "$p" == aur:* ]]; then
      aur+=("${p#aur:}")
    else
      native+=("$p")
    fi
  done

  [[ ${#native[@]} -gt 0 ]] && sudo pacman -S --needed --noconfirm "${native[@]}"
  [[ ${#aur[@]} -gt 0 ]] && yay -S --needed --noconfirm "${aur[@]}"
}

_install_ubuntu() {
  sudo apt-get install -y "$@"
}

_is_pkg_installed() {
  local pkg="$1"
  local clean_pkg="${pkg#*:}"
  local check_func="_check_${DISTRO}"

  if type "$check_func" &>/dev/null; then
    "$check_func" "$clean_pkg"
  else
    command -v "$clean_pkg" &>/dev/null
  fi
}

_exec_pkg_manager() {
  local install_func="_install_${DISTRO}"

  if type "$install_func" &>/dev/null; then
    "$install_func" "$@"
  else
    printfln "    ${RED}[!]${NC} No package manager defined for distro: $DISTRO"
    exit 1
  fi
}

require_pkgs() {
  local pkgs=("$@")
  local to_install=()
  local descriptions=()

  for raw_pkg in "${pkgs[@]}"; do
    local pkg
    pkg="$(_translate_pkg "$raw_pkg")"

    if [[ "$pkg" =~ ^(macos|arch|ubuntu|debian|linux): ]]; then
      local target_os="${pkg%%:*}"
      if [[ "$target_os" == "linux" && "$OS" != "linux" ]]; then continue; fi
      if [[ "$target_os" != "linux" && "$target_os" != "$DISTRO" ]]; then continue; fi
      pkg="${pkg#*:}"
    fi

    [[ "$pkg" == cask:* && "$DISTRO" != "macos" ]] && continue
    [[ "$pkg" == aur:* && "$DISTRO" != "arch" ]] && continue

    if ! _is_pkg_installed "$pkg"; then
      to_install+=("$pkg")
      descriptions+=("${pkg#*:}") # Clean names for the UI
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    export DOT_STEP_COUNT=$((DOT_STEP_COUNT + 1))
    local prefix="[${DOT_CURRENT_MODULE:-core}:${DOT_STEP_COUNT}]"
    printfln "\t${GREEN}[SKIP]${NC} ${prefix} The following packages are already installed."
    printfln "\t\t${YELLOW}[?]${NC} ${pkgs[*]}"
    return 0
  fi

  # Dry-Run Intercept
  if [[ "$DOT_DRY_RUN" == "1" ]]; then
    run "Install" true
    return 0
  fi

  step "Installing pkgs: ${descriptions[*]}" _exec_pkg_manager "${to_install[@]}"
}
require_custom() {
  local check_cmd=""
  local description=""
  local i_cond=""
  local target_os=""
  local cmd=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -c | --cmd)
      check_cmd="$2"
      shift 2
      ;;
    -m | --msg)
      description="$2"
      shift 2
      ;;
    -i)
      i_cond="$2"
      shift 2
      ;;
    -o | --os)
      target_os="$2"
      shift 2
      ;;
    --)
      shift 1
      break
      ;;
    -*)
      printfln "    ${RED}[!]${NC} Invalid flag for install_custom: $1"
      return 1
      ;;
    *)
      break
      ;;
    esac
  done

  cmd=("$@")
  if [[ -z "$description" ]]; then
    description="Install ${check_cmd:-custom package}"
  fi

  if [[ -n "$target_os" ]]; then
    if [[ "$target_os" == "linux" && "$OS" != "linux" ]]; then return 0; fi
    if [[ "$target_os" != "linux" && "$target_os" != "$DISTRO" ]]; then return 0; fi
  fi

  if [[ -n "$check_cmd" ]] && command -v "$check_cmd" &>/dev/null; then
    local prefix="[${DOT_CURRENT_MODULE:-core}:${DOT_STEP_COUNT}]"
    printfln "\t${GREEN}[SKIP]${NC} ${prefix} Skiping step \"${description}\" (Already installed)"
    return 0
  fi

  step -b "$description" "${cmd[@]}"
}
