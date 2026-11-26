#!/usr/bin/env bash

if false; then
  source "../dot.sh"
fi

assert [ "$OS" = "linux" ] -- \
  "Not on Linux" \
  "This module only works on Linux"

require_pkgs tailscale openssh
