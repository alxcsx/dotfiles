#!/usr/bin/env bash
# name:		macos.install.sh
# desc:		Configure the macos system.
# author:	Alex Candido <github:alxcsx>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/.utils/common.sh"

# Fail-fast: Only execute on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    printfln "${BLUE}[i]${NC} Not on macOS. Skipping macOS installation."
    exit 0
fi

validate_module_context
check_requirements "$SCRIPT_DIR"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# - Core Defaults
printfln "${BLUE}[i]${NC} Applying macOS system defaults..."

# Auto start
defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false
defaults write com.apple.loginwindow TALLogoutSavesState -bool false
## - Dock
defaults write com.apple.dock autohide-time-modifier -float 1
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 1000
defaults write com.apple.dock no-bouncing -bool true
defaults write com.apple.dock tilesize -int 16
defaults write com.apple.dock static-only -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock showhidden -bool true
## - Animation
defaults write com.apple.dock expose-animation-duration -float 0
defaults write com.apple.dock workspaces-swoosh-animation-off -bool true
defaults write com.apple.finder DisableAllAnimations -bool true
## - Topbar
defaults write NSGlobalDomain _HIHideMenuBar -bool true
## - Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.Terminal StringEncodings -array 4
## - Workspaces
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock workspaces-auto-swoosh -bool false
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
## - Desktop
defaults write com.apple.finder CreateDesktop -bool false
defaults write com.apple.WindowManager StandardHideWidgets -bool true
defaults write com.apple.WindowManager StageManagerHideWidgets -bool true

CURRENT_MUTE_STATE=$(nvram StartupMute 2>/dev/null | awk '{print $2}')
if [ ! "$CURRENT_MUTE_STATE" = "%01" ]; then
    printfln "${BLUE}[i]${NC} Muting startup sound..."
    sudo nvram StartupMute=%01
fi

# Third Party Apps
## - Itsycal
defaults write com.mowglii.ItsycalApp ShowEventPopoverOnHover -bool true
defaults write com.mowglii.ItsycalApp DoNotDrawOutlineAroundCurrentMonth -bool true
## - IINA
defaults write com.colliderli.iina AppleMenuBarVisibleInFullscreen -bool false
defaults write com.colliderli.iina iinaEnablePluginSystem -bool true

killall cfprefsd
killall Finder
killall Dock
killall WindowManager
killall SystemUIServer
killall Itsycal
# - Ricing
## - Borders and Top bar

printfln "${BLUE}[i]${NC} Setting up XDG config directories..."
mkdir -p "$CONFIG_DIR/sketchybar"
mkdir -p "$CONFIG_DIR/borders"

ln -sfn "$SCRIPT_DIR/sketchybar/plugins" "$CONFIG_DIR/sketchybar/plugins"
ln -sf "$SCRIPT_DIR/sketchybar/sketchybarrc" "$CONFIG_DIR/sketchybar/sketchybarrc"
ln -sf "$SCRIPT_DIR/borders/bordersrc" "$CONFIG_DIR/borders/bordersrc"

chmod +x "$CONFIG_DIR/sketchybar/sketchybarrc"
chmod +x "$CONFIG_DIR/borders/bordersrc"
chmod +x "$SCRIPT_DIR/sketchybar/plugins/"*.sh


printfln "${BLUE}[i]${NC} Starting visual presentation services..."

brew services start sketchybar
brew services start borders

## - Yabai
printfln "${BLUE}[i]${NC} Configuring Yabai..."
### - Permissions
YABAI_PATH="$(brew --prefix)/bin/yabai"
SUDOERS_FILE="/private/etc/sudoers.d/yabai"
HASH_CACHE_FILE="$CONFIG_DIR/yabai/last_sa_hash" 
CURRENT_HASH="$(shasum -a 256 "$YABAI_PATH" | awk '{print $1}')"

if [ -f "$HASH_CACHE_FILE" ] && [ "$(cat "$HASH_CACHE_FILE")" = "$CURRENT_HASH" ]; then
    printfln "${GREEN}[>]${NC} Yabai sudoers hash is already up to date. (Skipping sudo)"
else
    printfln "${YELLOW}[>] Yabai hash changed or missing. Updating sudoers...${NC}"
    
    YABAI_SUDOERS_LINE="$(whoami) ALL=(root) NOPASSWD: sha256:${CURRENT_HASH} ${YABAI_PATH} --load-sa"
    
    printfln "$YABAI_SUDOERS_LINE" | sudo tee "$SUDOERS_FILE" >/dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    
    # Save the new hash to our local cache so it doesn't prompt next time
    mkdir -p "$(dirname "$HASH_CACHE_FILE")"
    printfln "$CURRENT_HASH" > "$HASH_CACHE_FILE"
fi

### - config
YABAI_CONFIG_DIR="$CONFIG_DIR/yabai"
mkdir -p "$YABAI_CONFIG_DIR"
ln -sf "$SCRIPT_DIR/yabai/yabairc" "$YABAI_CONFIG_DIR/yabairc"


yabai --start-service

## - Karabiner
mkdir -p "$CONFIG_DIR/karabiner"
ln -sf "$SCRIPT_DIR/karabiner/karabiner.edn" "$CONFIG_DIR/karabiner/karabiner.edn"

export GOKU_EDN_CONFIG_FILE="$CONFIG_DIR/karabiner/karabiner.edn"
goku

append_rc "MACOS" "$(cat <<'SHELL'
export GOKU_EDN_CONFIG_FILE="$XDG_CONFIG_HOME/karabiner/karabiner.edn"
launchctl setenv GOKU_EDN_CONFIG_FILE "$XDG_CONFIG_HOME/karabiner/karabiner.edn"
SHELL
)"

