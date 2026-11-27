#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
gate="$root/ai/bin/agent-gate"
ask="$root/ai/bin/ask"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fake hc binary that records notifications and exits 0.
fake_hc="$tmp/hc"
cat >"$fake_hc" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_HC_LOG"
EOF
chmod +x "$fake_hc"

export AGENT_GATE_DIR="$tmp/gate"
export AGENT_GATE_HC="$fake_hc"
export AGENT_GATE_TIMEOUT=5
export FAKE_HC_LOG="$tmp/hc.log"

# 1. Direct sudo is always denied (even without ASK_PARENT).
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"sudo apt update"}}' | "$gate" --client codex)
jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null <<<"$out"
grep -q 'privileged-request' <<<"$out"

# 2. privileged-request is allowed.
out=$(printf '%s' '{"toolName":"bash","toolArgs":{"command":"privileged-request run \"install pkg\""}}' | "$gate" --client copilot)
jq -e '.permissionDecision == "allow"' >/dev/null <<<"$out"

# 3. Read-only spec blocks writes.
out=$(printf '%s' '{"toolName":"write","toolArgs":{"path":"foo.txt"}}' | ASK_PARENT=t1 ASK_READONLY=1 "$gate" --client copilot)
jq -e '.permissionDecision == "deny"' >/dev/null <<<"$out"

# 4. git push escalates to orchestrator and succeeds when approved via `ask --allow`.
(
  for _ in {1..40}; do
    req=$(find "$AGENT_GATE_DIR/requests" -name '*.req.json' 2>/dev/null | head -n1 || true)
    if [ -n "$req" ]; then
      id=$(basename "$req" .req.json)
      "$ask" --allow "$id" "push ok" >/dev/null
      exit 0
    fi
    sleep 0.1
  done
  exit 1
) &
approver=$!

out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | ASK_PARENT=t1 "$gate" --client codex)
wait "$approver"
jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null <<<"$out"
grep -q 'PERM_REQUEST(' "$FAKE_HC_LOG"

# 5. Orchestrator denial returns deny + reason to copilot.
(
  for _ in {1..40}; do
    req=$(find "$AGENT_GATE_DIR/requests" -name '*.req.json' 2>/dev/null | head -n1 || true)
    if [ -n "$req" ]; then
      id=$(basename "$req" .req.json)
      "$ask" --deny "$id" "not ready" >/dev/null
      exit 0
    fi
    sleep 0.1
  done
  exit 1
) &
denier=$!

out=$(printf '%s' '{"toolName":"bash","toolArgs":{"command":"git push origin main"}}' | ASK_PARENT=t1 "$gate" --client copilot)
wait "$denier"
jq -e '.permissionDecision == "deny" and .permissionDecisionReason == "not ready"' >/dev/null <<<"$out"

# 6. Internal tools (ask --reply with keywords/semicolons in quotes, hc ls, agent-quota) are allowed.
out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ask --reply t72 \"Done; git push worked, sudo not needed, curl ok\""}}' | ASK_PARENT=t1 "$gate" --client codex)
jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null <<<"$out"

out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"hc ls --json"}}' | ASK_PARENT=t1 "$gate" --client codex)
jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null <<<"$out"

# 7. Command substitution or chaining on internal tools is NOT bypassed.
out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ask --reply t72 \"$(sudo id)\""}}' | ASK_PARENT=t1 "$gate" --client codex)
jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null <<<"$out"

out=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"privileged-request check && sudo id"}}' | ASK_PARENT=t1 "$gate" --client codex)
jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null <<<"$out"

# 8. Codex execpolicy rules allow internal tools, block sudo, and do not allow hc run.
if command -v codex >/dev/null 2>&1; then
  rules="$root/ai/codex/rules/internal.rules"
  codex execpolicy check -r "$rules" -- ask --reply t72 "done" | jq -e '.decision == "allow"' >/dev/null
  codex execpolicy check -r "$rules" -- hc send t72 "hi" | jq -e '.decision == "allow"' >/dev/null
  codex execpolicy check -r "$rules" -- agent-quota | jq -e '.decision == "allow"' >/dev/null
  codex execpolicy check -r "$rules" -- sudo apt update | jq -e '.decision == "forbidden"' >/dev/null
  codex execpolicy check -r "$rules" -- hc run bash | jq -e '.decision == null' >/dev/null
fi

# 9. Stop hook sends REPORT(...) to parent and cleans up pane state.
mkdir -p "$AGENT_GATE_DIR/panes"
printf '{"parent":"t1","readonly":true,"files":[]}\n' >"$AGENT_GATE_DIR/panes/t99.json"
HC_TERMINAL_ID=t99 "$gate" --client claude --event stop <<<'{"hook_event_name":"Stop","last_assistant_message":"all done"}'
[ ! -f "$AGENT_GATE_DIR/panes/t99.json" ]
grep -q 'send t1 REPORT(t99): all done' "$FAKE_HC_LOG"
