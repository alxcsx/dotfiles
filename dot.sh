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
    echo "Help: $0 <command> [modules...]"
    echo ""
    echo "Commands:"
    echo "  install    Install [modules...]"
    echo "  uninstall  Uninstall [modules...]"
    echo "  status     Show status of all managed modules"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 install zsh mac"
    echo "  $0 uninstall emacs"
    echo "  $0 status"
    exit 1
}


if [ "$COMMAND" = "status" ]; then
    echo "Managed Modules Status:"
    echo "---------------------------"
    if [ -s "$STATE_FILE" ]; then
        while IFS='|' read -r mod stat ver; do
            printf "%-10s | %-10s | %s\n" "$mod" "$stat" "$ver"
        done < "$STATE_FILE"
    else
        echo "No managed modules found."
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
    echo "[!] Error: You must explicitly specify which modules to use."
    echo ""
    print_help
fi

echo "[i] Starting $COMMAND process..."

for module in $MODULES; do
    SCRIPT_PATH="$DOTFILES_DIR/$module/$COMMAND.sh"

    if [ -f "$SCRIPT_PATH" ]; then
        if [ "$COMMAND" = "install" ]; then
            echo "\n[+] Installing: $module"
        else
            echo "\n[-] Uninstalling: $module"
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
            echo "\n[!] Error: $module $COMMAND failed. State not updated."
        fi
    else
        echo "\n[!] Warning: Module '$module' is missing '$COMMAND.sh'"
    fi
done

echo "[i] All done!"