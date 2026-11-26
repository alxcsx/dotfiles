#!/usr/bin/env bash
# fleet-travel.sh — put the agent fleet down cleanly, and bring it back.
#
#   fleet-travel.sh depart     stop the fleet for travel
#   fleet-travel.sh return     bring it back
#   fleet-travel.sh status     what is running, and is anything mid-task
#
# WHY A SCRIPT AND NOT `systemctl --user stop`
#
# Closing the lid with Hyprland running SUSPENDS this machine. If the fleet is
# mid-task when that happens, the worker is frozen mid-run: its claim lock stays
# held until it expires, the card looks "running" for the whole trip, and the
# kanban dispatcher will not reclaim it until the lock times out. Stopping the
# units without pausing first leaves exactly that state.
#
# Order matters, and each step exists for a reason:
#   1. `hermes pause`   — halts NEW work only. In-flight work is never killed, so
#                         this is the safe first move rather than a stop.
#   2. wait for drain   — let running cards finish so no claim lock is orphaned.
#   3. stop units       — now nothing is mid-run, so stopping is clean.
#
# WC: never leave a running card across a suspend.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNITS=(hermes-gateway llamacpp-daemon)
DRAIN_TIMEOUT_S=${DRAIN_TIMEOUT_S:-900}

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

running_tasks() {
  hermes kanban list --json 2>/dev/null | python3 -c "
import json,sys
try:
    ts=json.load(sys.stdin)
except Exception:
    sys.exit(0)
n=[t for t in ts if t.get('status')=='running']
for t in n: print(f\"  {t['id']}  {t.get('assignee') or '?':<12} {(t.get('title') or '')[:60]}\")
print(len(n))
" 2>/dev/null
}

cmd_status() {
  echo "units:"
  for u in "${UNITS[@]}"; do
    printf '  %-18s %s\n' "$u" "$(systemctl --user is-active "$u" 2>/dev/null || echo unknown)"
  done
  local out n
  out=$(running_tasks); n=$(echo "$out" | tail -1)
  if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
    echo "running cards ($n):"
    echo "$out" | head -n -1
  else
    echo "running cards: none"
  fi
  echo -n "fleet dispatch: "
  hermes status 2>/dev/null | grep -i -m1 -E 'paused|running' || echo "(unknown)"
}

cmd_depart() {
  echo "== depart =="
  echo "1. pausing new work (does not kill in-flight)"
  hermes pause --reason "travel" 2>&1 | tail -2 | sed 's/^/   /'

  echo "2. waiting for in-flight cards to drain (up to ${DRAIN_TIMEOUT_S}s)"
  local waited=0 n
  while [ "$waited" -lt "$DRAIN_TIMEOUT_S" ]; do
    n=$(running_tasks | tail -1)
    if [ "${n:-0}" = "0" ]; then echo "   drained after ${waited}s"; break; fi
    [ $((waited % 60)) -eq 0 ] && echo "   ${waited}s — $n still running"
    sleep 15; waited=$((waited + 15))
  done
  if [ "${n:-0}" != "0" ]; then
    echo "   WARNING: $n card(s) still running after ${DRAIN_TIMEOUT_S}s."
    echo "   Stopping anyway would orphan their claim locks."
    echo "   Re-run 'depart' later, or stop manually once they finish:"
    running_tasks | head -n -1
    return 1
  fi

  echo "3. stopping units"
  for u in "${UNITS[@]}"; do
    if systemctl --user is-active "$u" >/dev/null 2>&1; then
      systemctl --user stop "$u" 2>&1 | tail -1 | sed "s/^/   $u: /"
    else
      echo "   $u: already stopped"
    fi
  done
  echo
  echo "fleet is down. Safe to close the lid / travel."
  echo "Note: units are still ENABLED, so they start again on boot."
  echo "      On arrival: $HERE/fleet-travel.sh return"
}

cmd_return() {
  echo "== return =="
  for u in llamacpp-daemon hermes-gateway; do
    systemctl --user start "$u" 2>&1 | tail -1 | sed "s/^/   $u: /"
  done
  echo "   waiting for the model server"
  for _ in $(seq 1 30); do
    curl -s -o /dev/null -m 3 http://127.0.0.1:58000/v1/models && break
    sleep 2
  done
  echo "   lifting the pause"
  hermes resume 2>&1 | tail -2 | sed 's/^/   /'
  echo
  "$HERE/fleet-check.py" || true
  echo "fleet is up."
}

case "${1:-}" in
  depart) cmd_depart ;;
  return) cmd_return ;;
  status|"") cmd_status ;;
  *) echo "usage: $0 {depart|return|status}" >&2; exit 2 ;;
esac
