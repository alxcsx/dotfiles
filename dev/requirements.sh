#!/bin/bash
# name:		dev.requirements.sh
# desc:		requirements for dev module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../.utils/packages_v2.sh"
fi

# --- Tools ---
require_pkgs \
  git \
  podman \
  podman-compose \
  direnv \
  fd \
  ripgrep \
  openssl \
  pkgconf \
  xh \
  bash-language-server \
  wxwidgets \
  libffi \
  unixodbc \
  "linux:inotify-tools"

require_custom \
  -c "mise" -- \
  curl https://mise.run | sh
