#!/bin/bash
# name:		ai.requirements.sh
# desc:		requirements for ai module
# author:	Alex Candido <github:alxcsx>

if false; then
  source "../dot.sh"
fi

# Node comes from the dev module (mise), and CLAUDE_CONFIG_DIR/COPILOT_HOME
# from dev/xdg_env.sh — install the dev module first. node merges the agent
# settings files; npx runs the MCP servers.
assert [ -n "$(command -v npm)" ] -- \
  "npm not found" \
  "Install the dev module first (it provides mise + node + npm env)"

# --- Claude Code, Codex + Copilot CLI ---
require_pkgs \
  arch:aur:claude-code \
  arch:openai-codex \
  macos:cask:claude-code \
  macos:cask:codex \
  macos:cask:copilot-cli

# --- Tools agents lean on: structural search, data/SQL, diffs, benchmarks ---
# Prebuilt binaries via mise/uv: Homebrew has no bottles for most of these on
# older macOS and would compile rust + llvm from source.
# difftastic and duckdb come straight from GitHub releases: mise's default
# (aqua) entries don't match their current macOS arm64 asset names.
mise_tool() { step "Install or update $2 (mise)" mise use --global "$2@latest"; }
mise_tool ast-grep ast-grep
mise_tool hyperfine hyperfine
mise_tool yq yq
mise_tool shfmt shfmt
mise_tool difft github:Wilfred/difftastic
mise_tool duckdb github:duckdb/duckdb
mise_tool scc github:boyter/scc

for tool in pgcli sqlfluff check-jsonschema; do
  step "Install or update $tool (uv)" uv tool install --upgrade "$tool"
done

require_pkgs jq arch:bubblewrap arch:chromium

# GDScript formatter/linter (gdformat, gdlint) for Godot 4 projects.
step "Install or update gdformat (uv)" \
  uv tool install --upgrade "gdtoolkit==4.*"

# Claude Code usage per 5-hour window.
step "Install or update ccusage (npm)" \
  npm install -g ccusage@latest
