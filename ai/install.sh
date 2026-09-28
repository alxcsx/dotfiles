#!/usr/bin/env bash
# name:		ai.install.sh
# desc:		Configure AI tooling (pi agent, MCP servers, llama.cpp server).
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

step "Setup Config Directories" \
  mkdir -p "$CONFIG_DIR/pi" "$CONFIG_DIR/mcp"

link_file "$MODULE_DIR/pi/settings.json" "$CONFIG_DIR/pi/settings.json"
link_file "$MODULE_DIR/pi/router-config.json" "$CONFIG_DIR/pi/router-config.json"
link_file "$MODULE_DIR/pi/caveman.json" "$CONFIG_DIR/pi/caveman.json"
link_file "$MODULE_DIR/mcp.json" "$CONFIG_DIR/mcp/mcp.json"

# auth.json (API keys) is intentionally NOT linked — this repo is public.

## - llama.cpp server (local model backend for pi) — Linux only (systemd)
if [ "$OS" = "linux" ]; then
  step "Setup llama.cpp Config Directory" \
    mkdir -p "$CONFIG_DIR/llamacpp/models" "$HOME/.config/systemd/user"

  # Machine-local preset: never committed. Seed from example if missing.
  step --skip-if '[ -f "$CONFIG_DIR/llamacpp/models-preset.ini" ]' \
    "Seed models-preset.ini from example" \
    cp "$MODULE_DIR/llamacpp/models-preset.ini.example" "$CONFIG_DIR/llamacpp/models-preset.ini"

  link_file "$MODULE_DIR/llamacpp/llama-router.sh" "$CONFIG_DIR/llamacpp/llama-router.sh"
  link_file "$MODULE_DIR/llamacpp/llamacpp-daemon.service" "$CONFIG_DIR/llamacpp/llamacpp-daemon.service"
  link_file "$MODULE_DIR/llamacpp/.gitignore" "$CONFIG_DIR/llamacpp/.gitignore"
  link_file -m "Link llama daemon unit to systemd user dir" \
    "$CONFIG_DIR/llamacpp/llamacpp-daemon.service" \
    "$HOME/.config/systemd/user/llamacpp-daemon.service"

  step "Reload systemd user units" systemctl --user daemon-reload

  step --skip-if 'systemctl --user is-enabled llamacpp-daemon.service >/dev/null 2>&1' \
    "Enable llama-server daemon" \
    systemctl --user enable --now llamacpp-daemon.service
fi
