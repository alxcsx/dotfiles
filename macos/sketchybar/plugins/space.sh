#!/bin/bash
# name:		sketchybar.space.sh
# desc:		workspace bar for sketchy bar.
# INFO:   It depends on the ctrl + number keybinds from mission control to switch between spaces.
# author:	Alex Candido <github:alxcsx>

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$PLUGIN_DIR/colors.sh"

if [ "$1" = "click" ]; then
  SPACE_ID=$2
  
  # Map the space number to the macOS key code
  case $SPACE_ID in
    1) KEY_CODE=18 ;;
    2) KEY_CODE=19 ;;
    3) KEY_CODE=20 ;;
    4) KEY_CODE=21 ;;
    5) KEY_CODE=23 ;;
    6) KEY_CODE=22 ;;
    *) exit 0 ;;
  esac
  
  osascript -e "tell application \"System Events\" to key code $KEY_CODE using control down"
  exit 0
fi

if [ "$SELECTED" = "true" ]; then
  sketchybar --set $NAME icon.color=$COLOR_YELLOW \
                         background.color=$ACTIVE_BG_COLOR
else
  sketchybar --set $NAME icon.color=$ICON_COLOR \
                         background.color=$ITEM_BG_COLOR
fi