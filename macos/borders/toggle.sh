#!/usr/bin/env bash
# name:		jankyborders.toggle.sh
# desc:		Toggle JankyBorders visibility
# author:	Alex Candido <github:alxcsx>

STATE_FILE="/tmp/borders_disabled"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    "$SCRIPT_DIR/bordersrc" >/dev/null 2>&1
    echo "Borders enabled"
else
    touch "$STATE_FILE"
    borders active_color=0x00000000 inactive_color=0x00000000 >/dev/null 2>&1
    echo "Borders disabled"
fi
