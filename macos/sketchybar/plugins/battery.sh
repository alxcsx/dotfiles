#!/bin/bash
# name:		sketchybar.battery.sh
# desc:		Battery for sketchy bar.
# author:	Alex Candido <github:alxcsx>``

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$PLUGIN_DIR/colors.sh"

BATT_PERCENT=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

if [[ $CHARGING != "" ]]; then
  ICON="󰂄"
  COLOR=$COLOR_GREEN
elif [[ $BATT_PERCENT -gt 80 ]]; then
  ICON="󰁹"
  COLOR=$LABEL_COLOR
elif [[ $BATT_PERCENT -gt 50 ]]; then
  ICON="󰁾"
  COLOR=$LABEL_COLOR
elif [[ $BATT_PERCENT -gt 20 ]]; then
  ICON="󰁼"
  COLOR=$COLOR_YELLOW
else
  ICON="󰂃"
  COLOR=$COLOR_RED
fi

sketchybar --set $NAME icon="$ICON" label="${BATT_PERCENT}%" icon.color="$COLOR"