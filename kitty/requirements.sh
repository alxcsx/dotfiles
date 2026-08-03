#!/bin/bash
# name:		kitty.requirements.sh
# desc:		requirements for kitty module
# author:	Alex Candido <github:alxcsx>
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.utils/packages.sh"

require "kitty" --cask