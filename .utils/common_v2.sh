#!/bin/bash
# name:		common_v2.sh
# desc:		Shared DSL executing install steps
# author:	Alex Candido <github:alxcsx>

## /From common_v1
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

printfln() {
  local format="$1"
  shift
  printf "%b\n" "$format" "$@" >&2
}

print_errorln() {
  local format="$1"
  shift
  local prefix="[${DOT_CURRENT_MODULE:-core}:${DOT_STEP_COUNT}]"
  printfln "${BOLD}${prefix}${NC} ${format}  ${YELLOW}->${NC} ${BASH_SOURCE[3]}:${BASH_LINENO[2]}" "$@"
}

## From common_v1/
run_remote_script() {
  local url="$1"
  shift
  curl -fsSL "$url" | sh -s -- "$@"
}

step() {
  ((DOT_STEP_COUNT++))
  case $DOT_ACTION in
  install)
    run_step "$@"
    ;;
  esac
}

run_step() {

  local backup=0
  local skip_condition=""
  local run_condition=""
  local strict_exit=0
  local interactive=0
  local verbose="$DOT_VERBOSE"
  local err_log=""

  # Parse DSL Flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -b | --backup)
      backup=1
      shift 1
      ;;
    --run-if)
      run_condition="$2"
      shift 2
      ;;
    --skip-if)
      skip_condition="$2"
      shift 2
      ;;
    -e | --exit)
      strict_exit=1
      shift 1
      ;;
    -I | --interactive)
      interactive=1
      shift 1
      ;;
    -v | --verbose)
      verbose=1
      shift 1
      ;;
    -*)
      print_errorln "\t${RED}[!]${prefix}${NC} Invalid flag: $1"
      exit 1
      ;;
    *) break ;; # End of flags, move to positional args
    esac
  done

  local description="$1"
  shift
  local cmd=("$@")
  local prefix="[${DOT_CURRENT_MODULE:-core}:${DOT_STEP_COUNT}]"
  printfln "${BLUE}${prefix}${YELLOW}[|>]${NC} ${BOLD}${description}.${NC}"

  # skip_condition to execute
  if [[ -n "$skip_condition" ]]; then
    if eval "$skip_condition"; then
      printfln "\t${GREEN}[SKIP]${NC} ${prefix} Skiping step \"${description}\". Condition already met."
      [[ $verbose -eq 1 ]] && printfln "\t\t${RED}[VERBOSE]${NC} condition: $skip_condition"
      return 0
    fi
  fi

  #run_condition
  if [[ -n "$run_condition" ]]; then
    if ! eval "$run_condition"; then
      printfln "\t${YELLOW}[NOOP]${NC} Skiping step \"${description}\". Condition to run not met."
      [[ $verbose -eq 1 ]] && printfln "\t\t${RED}[VERBOSE]${NC} condition: $run_condition"
      return 0
    fi
  fi

  # Handle DRY-RUN
  if [[ "$DOT_DRY_RUN" == "1" ]]; then
    printfln "\t${YELLOW}[DRY-RUN]${NC} Would execute: ${cmd[*]}"
    [[ $backup -eq 1 ]] && printfln "\t${YELLOW}[DRY-RUN]${NC} Would backup target."
    return 0
  fi

  local payload=""
  if [[ ! -t 0 ]]; then
    payload=$(cat)
  fi
  # If there's any data in STDIN (heredocs, for example), then substitute the first "-" on the called command.
  if [[ -n "$payload" ]]; then
    for i in "${!cmd[@]}"; do
      if [[ "${cmd[i]}" == "-" ]]; then
        cmd[i]="$payload"
        break # Only replace the first instance
      fi
    done
  fi

  # Handle backups
  if [[ $backup -eq 1 ]]; then
    local target_file=""
    local base_cmd="${cmd[0]}"

    case "$base_cmd" in
    append_rc) # append_rc <payload> <target> <marker>
      target_file="${cmd[2]}"
      ;;
    git) # git clone <url> <target_dir>`
      target_file="${cmd[2]}"
      ;;
    *) # Default fallback: Assume the last argument is the target
      target_file="${cmd[${#cmd[@]} - 1]}"
      ;;
    esac
    # Only proceed if we found a target and it actually exists
    if [[ -n "$target_file" && (-f "$target_file" || -L "$target_file") ]]; then
      local abs_target
      abs_target="$(cd "$(dirname "$target_file")" >/dev/null 2>&1 && pwd)/$(basename "$target_file")"
      local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}"
      local backup_path="$state_dir/dotfiles/backups${abs_target}"
      mkdir -p "$(dirname "$backup_path")"
      mv "$target_file" "$backup_path"
      printfln "${BLUE}[BACKUP]${NC} Saved ${YELLOW}${target_file}${NC} to .backups/"
    fi
  fi

  # Execute action
  if [[ $interactive -eq 1 ]]; then # Prompt the user for something
    "${cmd[@]}"
    status=$?
  elif [[ $verbose -eq 1 || "$DOT_VERBOSE" == "1" ]]; then # Verbose Execution
    printfln "\t${YELLOW}--- Verbose Output ---${NC}"
    "${cmd[@]}" </dev/null
    status=$?
    printfln "\t${YELLOW}----------------------${NC}"
  else # Quiet Execution (Default)
    err_log=$(mktemp)
    status=0
    "${cmd[@]}" >/dev/null 2>"$err_log" || status=$?
  fi

  # Results
  local prefix="[${DOT_CURRENT_MODULE:-*}:${DOT_STEP_COUNT}]"
  if [[ $status -eq 0 ]]; then
    printfln "\t${GREEN}[OK]${NC} ${prefix} Success"
    [[ -f "$err_log" ]] && rm -f "$err_log"
    return 0
  else
    printfln "\t${RED}[!]${NC} ${prefix} Step failed!"
    if [[ -f "$err_log" ]]; then
      local err_msg
      err_msg=$(cat "$err_log")
      if [[ -n "$err_msg" ]]; then
        echo "$err_msg" | while read -r line; do
          printfln "\t\t${RED}$line${NC}"
        done
      fi
      rm -f "$err_log"
    fi
    if [[ $strict_exit -eq 1 || "$DOT_HALT_ON_ERROR" == "1" ]]; then
      exit 1
    fi
    return 1
  fi
}

assert() {
  case $DOT_ACTION in
  install)
    run_assert "$@"
    ;;
  esac
}

run_assert() {
  local error_msg="Assertion failed."
  local hint=""
  local cmd=()

  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then
      shift 1
      break
    fi
    cmd+=("$1")
    shift 1
  done

  [[ -n "$1" ]] && error_msg="$1"
  [[ -n "$2" ]] && hint="$2"

  if ! "${cmd[@]}"; then
    printfln "${RED}[FATAL]${NC} ${error_msg}"
    [[ -n "$hint" ]] && printfln "${YELLOW}[HINT]${NC} ${hint}"
    printfln "${RED}[!] Halting dotfiles execution.${NC}\n"
    exit 1
  fi
}

link_file() {
  local description=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -m | --msg)
      description="$2"
      shift 2
      ;;
    -*)
      printfln "${RED}[!]${NC} Invalid flag for link_file: $1"
      exit 1
      ;;
    *)
      break
      ;;
    esac
  done
  local target="$1"
  local dest="$2"

  [[ -z "$description" ]] && description="Symlink $(basename "$target")"

  step --skip-if '[[ "$target" -ef "$dest" ]]' \
    -b "$description" \
    ln -sfn "$target" "$dest"
}

link_dir_content() {
  local backup=0
  local prune=0
  local src_dir=""
  local dest_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -b | --backup)
      backup=1
      shift 1
      ;;
    --prune)
      prune=1
      shift 1
      ;;
    -*)
      printfln "${RED}[!]${NC} Invalid flag for link_dir_content: $1"
      exit 1
      ;;
    *)
      break
      ;;
    esac
  done
  src_dir="$1"
  dest_dir="$2"
  src_dir="$(cd "$src_dir" 2>/dev/null && pwd)"
  dest_dir="${dest_dir%/}"

  if [[ -z "$src_dir" || -z "$dest_dir" ]]; then
    printfln "    ${RED}[!]${NC} Usage: link_dir_content [-b] [--prune] <src> <dest>"
    exit 1
  fi

  printfln "${BLUE}[i]${NC} Syncing directory ${src_dir} -> ${dest_dir}"

  while IFS= read -u 9 -r src_file; do
    local rel_path="${src_file#$src_dir/}"
    local target_dest="$dest_dir/$rel_path"
    local target_parent
    target_parent="$(dirname "$target_dest")"

    if [[ ! -d "$target_parent" ]]; then
      step "Create dir $target_parent" mkdir -p "$target_parent"
    fi

    link_file -m "Link $rel_path ($src_file -> $target_dest)" "$src_file" "$target_dest"

  done 9< <(find "$src_dir" -type f)

  # 2. Prune dead symlinks in destination (Optional)
  if [[ $prune -eq 1 && -d "$dest_dir" ]]; then
    find "$dest_dir" -type l | while read -r symlink; do
      if [[ ! -e "$symlink" ]]; then
        step "Remove dead link $symlink" rm "$symlink"
      fi
    done
  fi
}

## MACOS SPECIFIC
macos_defaults() {
  local domain="$1"
  shift

  assert [ -n "$domain" ] -- "macos_defaults requires a domain as the first argument"

  while [ $# -ge 3 ]; do
    local key="$1"
    local type="$2"
    local val="$3"
    shift 3

    case "$DOT_ACTION" in
    revert)
      step -v "Restore macOS default: $domain -> $key" defaults delete "$domain" "$key" 2>/dev/null || true
      ;;
    install)
      local current_val
      current_val=$(defaults read "$domain" "$key" 2>/dev/null || echo "__UNSET__")

      if [ "$DOT_DRY_RUN" == "1" ]; then
        printfln "    ${YELLOW}[DRY-RUN]${NC} defaults write \"$domain\" \"$key\" -$type \"$val\" (Current: $current_val)"
      else
        step --skip-if '[ "$current_val" == "$val" ]' \
          "Set macOS default: $domain -> $key ($val)" \
          defaults write "$domain" "$key" "-$type" "$val"
      fi
      ;;
    *)

      ;;
    esac
  done
}

## RC (from common_v1)

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
  local shell_name=""
  local rc_file=""

  shell_name="$(basename "$SHELL")"

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
