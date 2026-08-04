#!/bin/bash
# name:		sketchybar.wifi.sh
# desc:		wifi icon for sketchy bar.
# TODO:   Signal Strenght and Network Name aren't available without permisison. 
# author:	Alex Candido <github:alxcsx>

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$CONFIG_DIR/plugins"

source "$PLUGIN_DIR/colors.sh"

ACTIVE_IFACE=$(route -n get default 2>/dev/null | awk '/interface: / {print $2}')
WIFI_IFACE=$(networksetup -listallhardwareports | awk '/Hardware Port: (Wi-Fi|AirPort)/ {getline; print $2}')

if [ -z "$ACTIVE_IFACE" ]; then
  sketchybar --set $NAME icon="󰤭" icon.color=$COLOR_RED
  exit 0
fi

# 4. Determine connection type and update SketchyBar
if [ "$ACTIVE_IFACE" = "$WIFI_IFACE" ]; then  
  RSSI=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ agrCtlRSSI/ {print $2}')
  
  # Default to full signal
  ICON="󰤨" 
  COLOR=$COLOR_BLUE

  # Adjust icon and color based on signal strength
  if [ -n "$RSSI" ]; then
    if [ "$RSSI" -ge -60 ]; then
      ICON="󰤨" # Full signal
      COLOR=$COLOR_BLUE
    elif [ "$RSSI" -ge -70 ]; then
      ICON="󰤥" # Good signal
      COLOR=$COLOR_BLUE
    elif [ "$RSSI" -ge -80 ]; then
      ICON="󰤢" # Fair signal
      COLOR=$COLOR_YELLOW
    else
      ICON="󰤟" # Weak signal
      COLOR=$COLOR_RED
    fi
  fi

  sketchybar --set $NAME icon="$ICON" icon.color=$COLOR

else
  # WIRED/ETHERNET CONNECTION
  sketchybar --set $NAME icon="󰈀" icon.color=$COLOR_GREEN
fi

