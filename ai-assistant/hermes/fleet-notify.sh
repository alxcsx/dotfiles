#!/usr/bin/env bash
# fleet-notify.sh — run fleet-check and push to Telegram, without crying wolf.
#
# WHY: fleet-check runs every 15 minutes. A persistent problem — a card parked on a
# bad assignee — was re-sent on every tick, dozens of times. An alert that repeats
# unchanged is one people learn to ignore, which is worse than no alert. So: send
# when the content CHANGES, and re-send an unchanged body only after
# RE_NOTIFY_AFTER, so a long outage is not silently forgotten.
#
# Silent when healthy (fleet-check prints nothing -> nothing to send).
#
# FLEET_NOTIFY_DRY_RUN=1 prints what it WOULD send and touches no state. That exists
# because this script resets PATH below, so a test cannot stub `hermes` from outside
# — the first version of this file could not be tested without sending real messages.
# Sends via fleet-tg-send.py, NOT `hermes send`: the send tool cannot attach an
# inline keyboard, so alerts arrived as bare text. The helper hits the Bot API
# directly and adds URL buttons per stale card (`hermes send` remains the tool
# for anything without buttons).
#
# To test without sending: FLEET_NOTIFY_DRY_RUN=1, plus
# `fleet-tg-send.py --self-test` for the button layout.
set -uo pipefail

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
STATE="$HOME/.local/state/hermes-fleet-notify"
RE_NOTIFY_AFTER=$((24 * 3600))  # re-send an identical alert once a day
DRY_RUN="${FLEET_NOTIFY_DRY_RUN:-0}"

mkdir -p "$(dirname "$STATE")"

body=$("$HERE/fleet-check.py")
if [ -z "$body" ]; then
  # Healthy again: clear the memory so the NEXT problem is reported immediately.
  [ "$DRY_RUN" = 1 ] || rm -f "$STATE.hash" "$STATE.body" "$STATE.time"
  exit 0
fi

# Strip embedded ages (`22h19m`, `157 min`) before hashing: they change every
# minute, so the raw body never hashes stable and "changed" fired on every
# 15-minute tick — a parked blocked card paged dozens of times a day.
norm=$(printf '%s' "$body" | sed -E 's/[0-9]+h[0-9]{2}m//g; s/[0-9]+ min//g; s/[0-9]+m\b//g')
hash=$(printf '%s' "$norm" | sha256sum | cut -d' ' -f1)
last_hash=$(cat "$STATE.hash" 2>/dev/null || echo "")
last_time=$(cat "$STATE.time" 2>/dev/null || echo 0)
now=$(date +%s)

send=0
reason=""
if [ "$hash" != "$last_hash" ]; then
  send=1; reason="changed"
elif [ $((now - last_time)) -ge "$RE_NOTIFY_AFTER" ]; then
  send=1; reason="still unresolved after $(( (now - last_time) / 3600 ))h"
fi

[ "$send" = 1 ] || exit 0

# Build the message in a variable, NOT in a `{ ...; } | cmd` group. The first version
# used a group whose last command was a test that evaluates false on the "changed"
# path; with `set -o pipefail` that made the whole pipeline report failure even though
# hermes send succeeded, so the state was never stored and every identical run
# re-sent. Three real messages reached the operator before this was found.
msg="$body"
if [ -n "$reason" ] && [ "$reason" != "changed" ]; then
  msg="${msg}"$'\n\n  (unchanged — '"${reason}"')'
fi

if [ "$DRY_RUN" = 1 ]; then
  printf '  [dry-run] would send (%s):\n' "$reason"
  printf '%s\n' "$msg" | sed 's/^/    /'
  exit 0
fi

if printf '%s\n' "$msg" | python3 "$HERE/fleet-tg-send.py" >/dev/null 2>&1; then
  printf '%s' "$hash" > "$STATE.hash"
  printf '%s' "$now"  > "$STATE.time"
fi
exit 0
