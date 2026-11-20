#!/usr/bin/env bash
# name:		ai.install.sh
# desc:		Configure AI agents (omp, Claude Code, Copilot, agy) and their orchestration.
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
OMP_HOME="$HOME/.omp/agent"
OMP_BIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/omp/bin"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$CONFIG_DIR/claude}"
COPILOT_DIR="${COPILOT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/copilot}"
AGENTS_MD="$MODULE_DIR/agents/AGENTS.md"

# Installers drop binaries here; make them resolvable in this shell too.
export PATH="$BIN_DIR:$PATH"

# Deep-merge repo defaults into a settings file that tools (and Herdr's hooks)
# also write to, so it can't be a symlink. --check exits 0 when up to date.
merge_json() {
  node - "$@" <<'JS'
const fs = require("fs");
const args = process.argv.slice(2);
const check = args[0] === "--check";
const [src, dest] = check ? args.slice(1) : args;
const read = (f) => (fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, "utf8")) : {});
const isObj = (v) => v && typeof v === "object" && !Array.isArray(v);
const merge = (a, b) => {
  for (const [k, v] of Object.entries(b)) a[k] = isObj(v) && isObj(a[k]) ? merge(a[k], v) : v;
  return a;
};
const before = read(dest);
const after = merge(structuredClone(before), read(src));
const changed = JSON.stringify(before) !== JSON.stringify(after);
if (check) process.exit(changed ? 1 : 0);
if (changed) fs.writeFileSync(dest, JSON.stringify(after, null, 2) + "\n");
JS
}

## - omp + Herdr cross-agent orchestration (omp, agy, claude, copilot over hc) --
install_omp() {
  PI_INSTALL_DIR="$OMP_BIN_DIR" run_remote_script "https://omp.sh/install"
}

install_herdr() {
  HERDR_INSTALL_DIR="$BIN_DIR" run_remote_script "https://herdr.dev/install.sh"
}

install_hc() {
  HC_INSTALL_DIR="$BIN_DIR" run_remote_script "https://releases.herdr.dev/core/install.sh"
}

install_herdr_app() {
  run_remote_script "https://releases.herdr.dev/app/install.sh"
}

step --skip-if '[ -x "$OMP_BIN_DIR/omp" ]' "Install omp" install_omp
step --skip-if 'command -v herdr >/dev/null 2>&1' "Install herdr TUI" install_herdr
step --skip-if 'command -v hc >/dev/null 2>&1' "Install herdr-core (hc)" install_hc
step --skip-if 'command -v herdr-app >/dev/null 2>&1 || [ -d "$HOME/Applications/Herdr.app" ] || [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/herdr-app" ]' \
  "Install Herdr app (GUI)" install_herdr_app

step "Create omp agent directory" mkdir -p "$OMP_HOME/extensions"
link_file "$MODULE_DIR/omp/config.yml" "$OMP_HOME/config.yml"
link_file "$MODULE_DIR/mcp.json" "$OMP_HOME/mcp.json"
link_file -m "Install omp launcher" "$MODULE_DIR/bin/omp" "$BIN_DIR/omp"

# One instruction file for every agent (omp skips the other agents' copies
# via disabledExtensions in omp/config.yml).
link_file -m "Link agent rules for omp" "$AGENTS_MD" "$OMP_HOME/AGENTS.md"

step "Create Antigravity config directory" mkdir -p "$HOME/.gemini/config"
link_file -m "Link agent rules for agy" "$AGENTS_MD" "$HOME/.gemini/GEMINI.md"

step "Create Claude Code config directory" mkdir -p "$CLAUDE_HOME/agents"
step --skip-if 'merge_json --check "$MODULE_DIR/claude/settings.json" "$CLAUDE_HOME/settings.json"' \
  "Merge Claude Code settings" \
  merge_json "$MODULE_DIR/claude/settings.json" "$CLAUDE_HOME/settings.json"
link_file -m "Link agent rules for Claude Code" "$AGENTS_MD" "$CLAUDE_HOME/CLAUDE.md"
link_file "$MODULE_DIR/claude/agents/reviewer.md" "$CLAUDE_HOME/agents/reviewer.md"

# enabledPlugins (claude/settings.json) only switches plugins on; fetch them too.
install_claude_plugins() {
  local p installed
  installed=$(claude plugin list 2>/dev/null)
  for p in $(node -e 'console.log(Object.keys(require(process.argv[1]).enabledPlugins).join(" "))' \
    "$MODULE_DIR/claude/settings.json"); do
    grep -qF "$p" <<<"$installed" || claude plugin install -y "$p" || return 1
  done
}
step "Install Claude Code plugins" install_claude_plugins

step "Create Copilot config directory" mkdir -p "$COPILOT_DIR"
step --skip-if 'merge_json --check "$MODULE_DIR/copilot/settings.json" "$COPILOT_DIR/settings.json"' \
  "Merge Copilot settings" \
  merge_json "$MODULE_DIR/copilot/settings.json" "$COPILOT_DIR/settings.json"
link_file -m "Link agent rules for Copilot" "$AGENTS_MD" "$COPILOT_DIR/copilot-instructions.md"

# unset PI_CODING_AGENT_DIR (stale in shells started before pi was retired)
# so herdr installs into omp's default agent dir.
step --skip-if '[ -f "$OMP_HOME/extensions/herdr-omp-agent-state.ts" ]' \
  "Install Herdr omp integration" \
  env -u PI_CODING_AGENT_DIR herdr integration install omp

step --skip-if '[ -f "$HOME/.gemini/config/hooks/herdr-agent-state.sh" ]' \
  "Install Herdr antigravity-cli integration" \
  herdr integration install antigravity-cli

step --skip-if '[ -f "$CLAUDE_HOME/hooks/herdr-agent-state.sh" ]' \
  "Install Herdr Claude Code integration" \
  env CLAUDE_CONFIG_DIR="$CLAUDE_HOME" herdr integration install claude

step --skip-if '[ -f "$COPILOT_DIR/hooks/herdr-agent-state.sh" ]' \
  "Install Herdr Copilot integration" \
  env COPILOT_HOME="$COPILOT_DIR" herdr integration install copilot

link_file -m "Install ask (agent delegation)" "$MODULE_DIR/bin/ask" "$BIN_DIR/ask"
link_file -m "Install orch launcher" "$MODULE_DIR/bin/orch" "$BIN_DIR/orch"
link_file -m "Install quota board" "$MODULE_DIR/bin/quota" "$BIN_DIR/quota"
link_file -m "Install agents-index" "$MODULE_DIR/bin/agents-index" "$BIN_DIR/agents-index"
step --run-if '[ -L "$BIN_DIR/dev-orch" ]' "Remove old dev-orch link" rm "$BIN_DIR/dev-orch"

## - Interactive account setup ------------------------------------------------
# Runs after every install step. Skipped when stdin is not a terminal (CI).
omp_logged_in() { omp models find deepseek-v4-pro 2>/dev/null | grep -q "deepseek-v4-pro"; }
agy_logged_in() { command -v agy >/dev/null 2>&1 && agy models >/dev/null 2>&1; }

step --run-if '[[ -t 0 ]] && ! omp_logged_in' -I \
  "Log in to OpenCode Go (omp)" \
  omp login opencode-go

step --run-if '[[ -t 0 ]] && command -v agy >/dev/null 2>&1 && ! agy_logged_in' -I \
  "Sign in to Antigravity CLI (agy), then run /exit" \
  agy

## - Retire pi (replaced by omp) -----------------------------------------------
# pi's standalone install, its credentials and its MCP link. Only once omp is
# logged in, so OpenCode Go access is never lost.
step --run-if '[ -d "$CONFIG_DIR/pi" ] && omp_logged_in' "Remove pi agent" \
  rm -rf "$CONFIG_DIR/pi" "$CONFIG_DIR/mcp" "$HOME/bin/pi"
