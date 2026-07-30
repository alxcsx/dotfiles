#!/bin/sh
# name:		dot.sh
# desc:		Dotfiles Manager
# author:	Alex Candido <github:alxcsx>

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

# Helper Functions
print_help() {
    echo "Help: $0 <command> [modules...]"
    echo ""
    echo "Commands:"
    echo "  install    Install modules (defaults to OS-specific smart list)"
    echo "  uninstall  Uninstall modules (requires explicit module names)"
    echo ""
    echo "Examples:"
    echo "  $0 install"
    echo "  $0 install zsh mac"
    echo "  $0 uninstall emacs"
    exit 1
}

COMMAND="$1"

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
    if [ "$COMMAND" = "uninstall" ]; then
        echo "[!] Error: You must explicitly specify which modules to uninstall."
        echo ""
        print_help
    fi

    MODULES="zsh emacs"
    
    if [ "$OS" = "Darwin" ]; then
        MODULES="$MODULES mac"
    fi
    
    echo "[i] No modules specified. Defaulting to: $MODULES"
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
        
        # Execute the module script, passing the base directory as an argument
        sh "$SCRIPT_PATH" "$DOTFILES_DIR"
    else
        echo "\n[!] Warning: Module '$module' is missing '$COMMAND.sh'"
    fi
done

echo "\n[i] All done!"