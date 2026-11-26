#!/usr/bin/env bash
# Optional Linux server module: local models and Hermes fleet tooling.

assert [ "$OS" = "linux" ] -- "Not on Linux" "The ai-assistant module requires Linux and systemd user services"

ASSISTANT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
ASSISTANT_BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
ASSISTANT_UNITS="$HOME/.config/systemd/user"

step "Create local assistant directories" mkdir -p \
  "$ASSISTANT_CONFIG_DIR/llamacpp/models" "$ASSISTANT_BIN_DIR" "$ASSISTANT_UNITS"

step --skip-if '[ -f "$ASSISTANT_CONFIG_DIR/llamacpp/models-preset.ini" ]' \
  "Seed local model preset" cp "$MODULE_DIR/llamacpp/models-preset.ini.example" \
  "$ASSISTANT_CONFIG_DIR/llamacpp/models-preset.ini"
link_file "$MODULE_DIR/llamacpp/llama-router.sh" "$ASSISTANT_CONFIG_DIR/llamacpp/llama-router.sh"
link_file "$MODULE_DIR/llamacpp/llamacpp-daemon.service" "$ASSISTANT_UNITS/llamacpp-daemon.service"
link_file "$MODULE_DIR/laya/laya-mcp-server" "$ASSISTANT_BIN_DIR/laya-mcp-server"
link_file "$MODULE_DIR/laya/laya-serve.service" "$ASSISTANT_UNITS/laya-serve.service"

for tool in fleet-apply.sh fleet-check.py fleet-travel.sh guard-private-egress.py \
  k fleet-notify.sh fleet-tg-send.py kanban-guards.sh capability-check backup.sh \
  btrfs-snapshot.sh cloudflare-ddns.py deck-check.py deck-to-pptx.py docs-snapshot.sh \
  egress-proxy.py exo-healthguard file-drop.py llm-bench.py maintenance-scan.sh \
  mc-gate mc-password mc-rotate-password.sh mc-sync-verified mc-verified share svc \
  tg-approve.py wan-check; do
  link_file "$MODULE_DIR/hermes/$tool" "$ASSISTANT_BIN_DIR/$tool"
done
for unit in "$MODULE_DIR"/hermes/*.service "$MODULE_DIR"/hermes/*.timer; do
  link_file "$unit" "$ASSISTANT_UNITS/$(basename "$unit")"
done
step "Reload systemd user units" systemctl --user daemon-reload
