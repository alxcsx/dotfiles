#!/bin/bash
# name:		dot.sh
# desc:		Dotfiles Manager
# author:	Alex Candido <github:alxcsx>

# startup
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"
COMMAND="$1"

source "$DOTFILES_DIR/.utils/common.sh"

# Helper Functions
print_help() {
    printfln "${BLUE}Help:${NC} $0 <command> [modules...]"
    echo ""
    printfln "${BLUE}Commands:${NC}"
    printfln "  ${GREEN}install${NC}    Install [modules...]"
    printfln "  ${GREEN}uninstall${NC}  Uninstall [modules...]"
    printfln "  ${GREEN}status${NC}     Show status of all managed modules"
    echo ""
    printfln "${BLUE}Examples:${NC}"
    printfln "  ${YELLOW}$0 install${NC}"
    printfln "  ${YELLOW}$0 install zsh mac${NC}"
    printfln "  ${YELLOW}$0 uninstall emacs${NC}"
    printfln "  ${YELLOW}$0 status${NC}"
    exit 1
}


if [ "$COMMAND" = "status" ]; then
    printfln "${BLUE}Managed Modules Status:${NC}"
    printfln "${BLUE}---------------------------${NC}"
    if [ -s "$STATE_FILE" ]; then
        while IFS='|' read -r mod stat ver; do
            printf "%-10s | %-10s | %s\n" "$mod" "$stat" "$ver"
        done < "$STATE_FILE"
    else
        printfln "${YELLOW}No managed modules found.${NC}"
    fi
    exit 0
fi

case "$COMMAND" in install|uninstall)
        shift
        ;;
    *)
        print_help
        ;;
esac

if [ $# -gt 0 ]; then
    MODULES="$@"
else
    printfln "${RED}[!] Error: You must explicitly specify which modules to use.${NC}"
    echo ""
    print_help
fi

printfln "${BLUE}[i]${NC} Starting $COMMAND process..."

for module in $MODULES; do
    SCRIPT_PATH="$DOTFILES_DIR/$module/$COMMAND.sh"

    if [ -f "$SCRIPT_PATH" ]; then
        if [ "$COMMAND" = "install" ]; then
            printfln "${GREEN}[+]${NC} Installing: $module"
        else
            printfln "${YELLOW}[-]${NC} Uninstalling: $module"
        fi

        # Execute the module script with DOTFILES_DIR in environment
        export DOTFILES_DIR
        sh "$SCRIPT_PATH"
        
        if [ $? -eq 0 ]; then # Check if the script succeeded before updating state
            if [ "$COMMAND" = "install" ]; then
                update_state "$module" "installed" "$(get_git_hash)"
            elif [ "$COMMAND" = "uninstall" ]; then
                remove_state "$module"
            fi
        else
            printfln "${RED}[!] Error: $module $COMMAND failed. State not updated.${NC}"
        fi
    else
        printfln "${YELLOW}[!] Warning:${NC} Module '$module' is missing '$COMMAND.sh'"
    fi
done

printfln "${GREEN}[i]${NC} All done!"