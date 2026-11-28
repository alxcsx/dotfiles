#!/usr/bin/env bash
# Optional Linux server module: local models and Hermes fleet tooling.

assert [ "$OS" = "linux" ] -- "Not on Linux" "The ai-assistant module requires Linux and systemd user services"

ASSISTANT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
ASSISTANT_BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
ASSISTANT_UNITS="$HOME/.config/systemd/user"

LOCAL_AI_DIR="$(cd "$(dirname "$MODULE_DIR")/local-ai" && pwd)"
step "Create local assistant directories" mkdir -p \
  "$ASSISTANT_BIN_DIR" "$ASSISTANT_UNITS"

if [ -f "$LOCAL_AI_DIR/install.sh" ]; then
  MODULE_DIR="$LOCAL_AI_DIR" source "$LOCAL_AI_DIR/install.sh"
fi
link_file "$MODULE_DIR/laya/laya-mcp-server" "$ASSISTANT_BIN_DIR/laya-mcp-server"
link_file "$MODULE_DIR/laya/laya-serve.service" "$ASSISTANT_UNITS/laya-serve.service"

for tool in fleet-apply.sh fleet-check.py fleet-travel.sh guard-private-egress.py \
  k fleet-notify.sh fleet-tg-send.py kanban-guards.sh capability-check \
  deck-check.py deck-to-pptx.py docs-snapshot.sh \
  egress-proxy.py file-drop.py llm-bench.py \
  svc tg-approve.py; do
  link_file "$MODULE_DIR/hermes/$tool" "$ASSISTANT_BIN_DIR/$tool"
done
for unit in "$MODULE_DIR"/hermes/*.service "$MODULE_DIR"/hermes/*.timer; do
  link_file "$unit" "$ASSISTANT_UNITS/$(basename "$unit")"
done
step "Reload systemd user units" systemctl --user daemon-reload
