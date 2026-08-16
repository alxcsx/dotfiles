#!/bin/bash
# name:		dot.sh
# desc:		Dotfiles Manager
# author:	Alex Candido <github:alxcsx>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR="$SCRIPT_DIR"

if false; then
  source "./.utils/common.sh"
  source "./.utils/packages.sh"
  source "./.utils/common_v2.sh"
  source "./.utils/packages_v2.sh"
fi

source "$DOTFILES_DIR/.utils/common.sh"
source "$DOTFILES_DIR/.utils/packages.sh"
source "$DOTFILES_DIR/.utils/packages_v2.sh"
source "$DOTFILES_DIR/.utils/common_v2.sh"

export DOT_VERBOSE=0
export DOT_DRY_RUN=0
export DOT_HALT_ON_ERROR=1
export DOT_CURRENT_MODULE=""
export DOT_STEP_COUNT=0
export DOT_ACTION=""
MODULES=()

# 3. Parse Global Arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  -v | --verbose)
    export DOT_VERBOSE=1
    shift 1
    ;;
  --dry-run)
    export DOT_DRY_RUN=1
    shift 1
    ;;
  --halt)
    export DOT_HALT_ON_ERROR=1
    shift 1
    ;;
  --no-halt)
    export DOT_HALT_ON_ERROR=0
    shift 1
    ;;
  install | status)
    DOT_ACTION="$1"
    shift 1
    ;;
  -*)
    printfln "${RED}[!]${NC} Unknown global flag: $1"
    exit 1
    ;;
  *)
    MODULES+=("$1")
    shift 1
    ;;
  esac
done

if [[ -z "$DOT_ACTION" || ("$DOT_ACTION" != "status" && ${#MODULES[@]} -eq 0) ]]; then
  printfln "\t${RED}[!]${NC} Usage: dot.sh [FLAGS] <install|status> <module1> [module2...]"
  printfln "\tFlags: -v/--verbose, --dry-run, --halt, --no-halt\n"
  exit 1
fi

# Keep sudo active
if [[ "$DOT_ACTION" == "install" && "$DOT_DRY_RUN" == "0" ]]; then
  printfln "${BLUE}[i]${NC} Authenticating sudo access for installation..."
  assert sudo -v -- "\tSudo authentication failed." "\tYou need admin rights to install dotfiles."
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
  printfln "${GREEN}[OK]${NC} Sudo credentials cached."
fi

printfln "\n${BLUE}[i]${NC} Starting dotfiles manager in ${YELLOW}${DOT_ACTION}${NC} mode..."
[[ "$DOT_DRY_RUN" == "1" ]] && printfln "    ${YELLOW}[!] DRY RUN ENABLED - No changes will be made to the system.${NC}"

case "$DOT_ACTION" in
install)
  for module in "${MODULES[@]}"; do
    export MODULE_DIR="$DOTFILES_DIR/$module"

    if [[ -f "$MODULE_DIR/install.sh" ]]; then
      printfln "${BLUE}=== [ Module: ${module} ] ===${NC}"
      export DOT_CURRENT_MODULE="$module"
      export DOT_STEP_COUNT=0
      printfln "${BLUE}[i]${NC} Verifying Module Requirements:"
      [[ -f "$MODULE_DIR/requirements.sh" ]] && source "$MODULE_DIR/requirements.sh"
      source "$MODULE_DIR/install.sh"
    else
      printfln "\n${YELLOW}[!]${NC} Skipping '$module': No install.sh script found."
    fi
  done
  ;;
status)
  printfln "${BLUE}Managed Modules Status:${NC}"
  printfln "${BLUE}---------------------------${NC}"
  if [ -s "$STATE_FILE" ]; then
    while IFS='|' read -r mod stat ver; do
      printf "%-10s | %-10s | %s\n" "$mod" "$stat" "$ver"
    done <"$STATE_FILE"
  else
    printfln "${YELLOW}No managed modules found.${NC}"
  fi
  exit 0
  ;;
esac

printfln "${GREEN}[OK]${NC} All tasks complete! 🎉\n"
