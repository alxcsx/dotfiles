#!/bin/bash
# name:		sketchybar.colors.sh
# desc:		Gruber Darker color palette for sketchy bar.
# author:	Alex Candido <github:alxcsx>

export BAR_COLOR=0xff181818        
export ITEM_BG_COLOR=0x00000000    # Transparent
export ACTIVE_BG_COLOR=0xff282828  

export ICON_COLOR=0xff95a99f       
export LABEL_COLOR=0xffe4e4ef      

export COLOR_RED=0xfff43841        # Gruber Red
export COLOR_GREEN=0xff73c936      # Gruber Green
export COLOR_YELLOW=0xffffdd33     # Gruber Yellow
export COLOR_BLUE=0xff96a6c8       # Gruber Blue

if [[ "$NAME" != *"space"* ]]; then
  if [ "$SENDER" = "mouse.entered" ]; then
    sketchybar --set "$NAME" background.color=$ACTIVE_BG_COLOR
    exit 0
  fi

  if [ "$SENDER" = "mouse.exited" ]; then
    sketchybar --set "$NAME" background.color=$ITEM_BG_COLOR
    exit 0
  fi
fi