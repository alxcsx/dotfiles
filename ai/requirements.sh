#!/bin/bash
# name:		ai.requirements.sh
# desc:		requirements for ai module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

# Node/npm comes from the dev module (mise), and NPM_CONFIG_PREFIX/PI_CODING_AGENT_DIR
# from dev/xdg_env.sh — install the dev module first.
assert [ -n "$(command -v npm)" ] -- \
  "npm not found" \
  "Install the dev module first (it provides mise + node + npm env)"

# --- Pi Agent ---
require_custom -c "pi" -- \
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# --- Local LLM backend (llama.cpp router server, port 58000) ---
require_pkgs \
  aur:llama.cpp-cuda-git
