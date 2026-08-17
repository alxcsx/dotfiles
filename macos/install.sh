#!/usr/bin/env bash
# name:		macos.install.sh
# desc:		Configure the macos system.
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

assert [ "$OS" = "darwin" ] -- \
  "Not on MACOS" \
  "This Module Only Works on Darwin Machines"


CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
# - Core Defaults

macos_defaults "com.apple.loginwindow" \
  "LoginwindowLaunchesRelaunchApps" "bool" "false" \
  "TALLogoutSavesState"             "bool" "false"

macos_defaults "com.apple.dock" \
  "autohide-time-modifier"          "float" "1" \
  "autohide"                        "bool"  "true" \
  "autohide-delay"                  "float" "1000" \
  "no-bouncing"                     "bool"  "true" \
  "tilesize"                        "int"   "16" \
  "static-only"                     "bool"  "true" \
  "show-recents"                    "bool"  "false" \
  "showhidden"                      "bool"  "true" \
  "expose-animation-duration"       "float" "0" \
  "workspaces-swoosh-animation-off" "bool"  "true" \
  "mru-spaces"                      "bool"  "false" \
  "workspaces-auto-swoosh"          "bool"  "false"

macos_defaults "com.apple.finder" \
  "DisableAllAnimations"            "bool"  "true" \
  "AppleShowAllFiles"               "bool"  "true" \
  "CreateDesktop"                   "bool"  "false"

macos_defaults "NSGlobalDomain" \
  "_HIHideMenuBar"                  "bool"  "true" \
  "AppleShowAllExtensions"          "bool"  "true" \
  "NSAutomaticWindowAnimationsEnabled" "bool" "false"

macos_defaults "com.apple.desktopservices" \
  "DSDontWriteNetworkStores"        "bool"  "true"

macos_defaults "com.apple.Terminal" \
  "StringEncodings"                 "array" "4"

macos_defaults "com.apple.WindowManager" \
  "EnableStandardClickToShowDesktop" "bool" "false" \
  "StandardHideWidgets"              "bool" "true" \
  "StageManagerHideWidgets"          "bool" "true"

macos_defaults "com.mowglii.ItsycalApp" \
  "ShowEventPopoverOnHover"          "bool" "true" \
  "DoNotDrawOutlineAroundCurrentMonth" "bool" "true"

macos_defaults "com.colliderli.iina" \
  "AppleMenuBarVisibleInFullscreen" "bool"  "false" \
  "iinaEnablePluginSystem"          "bool"  "true"

step "Restart affected macOS system services" bash -c 'killall cfprefsd Finder Dock WindowManager SystemUIServer Itsycal 2>/dev/null || true'

step --run-if '[ "$(nvram StartupMute 2>/dev/null | awk "{print \$2}")" != "%01" ]' -b \
  "Mute macOS Startup Sound" \
  sudo nvram StartupMute=%01

step "Setup Config Directories" \
  mkdir -p "$CONFIG_DIR/sketchybar" "$CONFIG_DIR/borders" "$CONFIG_DIR/yabai" "$CONFIG_DIR/karabiner"

link_dir_content "$MODULE_DIR/sketchybar/plugins" "$CONFIG_DIR/sketchybar/plugins"
link_file "$MODULE_DIR/sketchybar/sketchybarrc" "$CONFIG_DIR/sketchybar/sketchybarrc"
link_file "$MODULE_DIR/borders/bordersrc" "$CONFIG_DIR/borders/bordersrc"

step "Make Scripts Executable" \
     chmod +x "$CONFIG_DIR/sketchybar/sketchybarrc"\
     "$CONFIG_DIR/borders/bordersrc"\
     "$CONFIG_DIR/sketchybar/plugins/"*.sh


step "Start Visual Presentation Services" bash -c '
  brew services restart sketchybar
  brew services restart borders
'

## - Yabai
YABAI_PATH="$(brew --prefix)/bin/yabai"
SUDOERS_FILE="/private/etc/sudoers.d/yabai"
HASH_CACHE_FILE="$CONFIG_DIR/yabai/last_sa_hash"
CURRENT_HASH="$(shasum -a 256 "$YABAI_PATH" 2>/dev/null | awk '{print $1}')"

step --run-if '[ ! -f "'"$HASH_CACHE_FILE"'" ] || [ "$(cat "'"$HASH_CACHE_FILE"'")" != "'"$CURRENT_HASH"'" ]' -b \
  "Configure Yabai Sudoers & Scripting Addition" bash -c '
    YABAI_LINE="$(whoami) ALL=(root) NOPASSWD: sha256:'"$CURRENT_HASH"' '"$YABAI_PATH"' --load-sa"
    echo "$YABAI_LINE" | sudo tee "'"$SUDOERS_FILE"'" >/dev/null
    sudo chmod 440 "'"$SUDOERS_FILE"'"
    echo "'"$CURRENT_HASH"'" > "'"$HASH_CACHE_FILE"'"
'

link_file "$MODULE_DIR/yabai/yabairc" "$CONFIG_DIR/yabai/yabairc"

step "Start Yabai Service" \
  yabai --start-service

## - Karabiner
link_file "$MODULE_DIR/karabiner/karabiner.edn" "$CONFIG_DIR/karabiner/karabiner.edn"
step "Compile Karabiner Config via Goku" goku

append_rc_step "MACOS" "$(
  cat <<'SHELL'
export GOKU_EDN_CONFIG_FILE="$XDG_CONFIG_HOME/karabiner/karabiner.edn"
launchctl setenv GOKU_EDN_CONFIG_FILE "$XDG_CONFIG_HOME/karabiner/karabiner.edn"
SHELL
)"
