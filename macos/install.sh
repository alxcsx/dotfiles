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

GOKU_EDN_CONFIG_FILE="$XDG_CONFIG_HOME/karabiner/karabiner.edn"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
# - Core Defaults

macos_defaults "com.apple.loginwindow" \
  "LoginwindowLaunchesRelaunchApps" "bool" "false" \
  "TALLogoutSavesState"             "bool" "false"

macos_defaults "com.apple.dock" \
  "autohide"                        "bool"  "true" \
  "autohide-delay"                  "float" "0" \
  "autohide-time-modifier"          "float" "0.15" \
  "no-bouncing"                     "bool"  "true" \
  "tilesize"                        "int"   "32" \
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
               "_HIHideMenuBar"                     "bool"  "false" \
               "AppleShowAllExtensions"             "bool"  "true" \
               "NSAutomaticWindowAnimationsEnabled" "bool"  "false"

macos_defaults "com.apple.desktopservices" \
  "DSDontWriteNetworkStores"        "bool"  "true"

macos_defaults "com.apple.Terminal" \
  "StringEncodings"                 "array" "4"

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

step "Disable Window Recover"  defaults write -g NSQuitAlwaysKeepsWindows -bool false

step "Restart affected macOS system services" bash -c 'killall cfprefsd Finder Dock WindowManager SystemUIServer Itsycal 2>/dev/null || true'

step --run-if '[ "$(nvram StartupMute 2>/dev/null | awk "{print \$2}")" != "%01" ]' -b \
  "Mute macOS Startup Sound" \
  sudo nvram StartupMute=%01

step --skip-if '[ -f "$HOME/.hushlogin" ]' \
  "Suppress macOS last login message" \
  touch "$HOME/.hushlogin"

step "Setup Config Directories" \
  mkdir -p "$CONFIG_DIR/borders" "$CONFIG_DIR/aerospace" "$CONFIG_DIR/karabiner"

link_file "$MODULE_DIR/borders/bordersrc" "$CONFIG_DIR/borders/bordersrc"
link_file "$MODULE_DIR/aerospace/aerospace.toml" "$CONFIG_DIR/aerospace/aerospace.toml"

step \
  --skip-if '[ ! -f "$HOME/.aerospace.toml" ]' \
  "Remove auto-generated AeroSpace config to enforce XDG path" \
  rm -f "$HOME/.aerospace.toml"

step "Make Scripts Executable" \
     chmod +x "$CONFIG_DIR/borders/bordersrc"

step "Start Visual Presentation Services" bash -c '
  brew services restart borders
'

## - Karabiner
step \
  --skip-if "[ -f \"$CONFIG_DIR/karabiner/karabiner.json\" ]" \
  "Initialize minimal karabiner.json profile" \
  bash -c "echo '{\"profiles\": [{\"name\": \"Default profile\"}]}' > \"$CONFIG_DIR/karabiner/karabiner.json\""

link_file "$MODULE_DIR/karabiner/karabiner.edn" "$CONFIG_DIR/karabiner/karabiner.edn"
step "Compile Karabiner Config via Goku" goku

append_rc_step "MACOS" "$(
  cat <<'SHELL'
export GOKU_EDN_CONFIG_FILE="$XDG_CONFIG_HOME/karabiner/karabiner.edn"
launchctl setenv GOKU_EDN_CONFIG_FILE "$XDG_CONFIG_HOME/karabiner/karabiner.edn"
SHELL
)"
