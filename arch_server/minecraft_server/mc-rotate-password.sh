#!/usr/bin/env bash
# mc-rotate-password — rotate the Minecraft shared join password.
#
# Cadence is set by mc-rotate-password.timer (currently weekly), not by this
# script, so the name stays honest if it changes again.
#
# The server is public (no whitelist) but gated by PasswordWhitelist: to get past
# the join dialog a player needs the current shared password. This rotates it and
# sends the new one to Telegram so it can be forwarded to the class. Account
# ownership is separate — AuthMe still requires each player's own
# /register + /login.
#
# The password is applied over RCON, so this never restarts the server and
# players who are already in are not interrupted.
#
#   mc-rotate-password            rotate and announce
#   mc-rotate-password --dry-run  print what it would set, change nothing
#   mc-rotate-password --force    rotate even if the current one is fresh
#   MCPW_NOTIFY=0 mc-rotate-password   rotate silently
#
# Freshness guard: a rotation is skipped when the current password was set less
# than GUARD_HOURS ago. Without it, "fast-forwarding" a rotation (running this by
# hand shortly before the scheduled one) is undone hours later by the timer and
# the password you already handed out stops working. --force overrides.
#
# Read the current one with: mc-password
set -euo pipefail

NOTIFY=${MCPW_NOTIFY:-1}
DRY=0
FORCE=0
GUARD_HOURS=${MCPW_GUARD_HOURS:-12}
STORE=/home/alex/services/minecraft/data/plugins/PasswordWhitelist/data/password.properties
for arg in "$@"; do
  [ "$arg" = "--dry-run" ] && DRY=1
  [ "$arg" = "--force" ] && FORCE=1
done

# Two English words + two digits: easy to retype on a phone or dictate across a
# classroom, no accents. ~410k combinations, and it rotates with a 10-attempt
# limit per player, so brute force is not a concern. Switched from Portuguese to
# English at the owner's request (2026-10-18).
WORDS=(blue green tiger lion moon sun sea river stone fire wind rain cloud leaf
       tree house door book table pen coffee bread cheese milk train car boat
       plane bridge tower field beach hill valley spring bell guitar drum flute
       rose lemon mango grape melon banana apple strawberry cherry pear horse wolf
       bear fish eagle owl frog snake ant bee turtle dolphin whale fox deer)

generate() {
  local a b n
  a=${WORDS[$((RANDOM % ${#WORDS[@]}))]}
  b=${WORDS[$((RANDOM % ${#WORDS[@]}))]}
  while [ "$b" = "$a" ]; do b=${WORDS[$((RANDOM % ${#WORDS[@]}))]}; done
  n=$(printf '%02d' $((RANDOM % 100)))
  printf '%s-%s-%s' "$a" "$b" "$n"
}

PW=$(generate)

if [ "$DRY" = 1 ]; then
  echo "would set: $PW"
  exit 0
fi

if [ "$FORCE" = 0 ] && [ -f "$STORE" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$STORE") ))
  if [ "$age" -lt $(( GUARD_HOURS * 3600 )) ]; then
    echo "skipping: current password is $((age / 3600))h old (< ${GUARD_HOURS}h) — "
    echo "the scheduled rotation will pick it up. Use --force to rotate anyway."
    exit 0
  fi
fi

if ! podman container exists minecraft 2>/dev/null || ! podman ps --format '{{.Names}}' | grep -qx minecraft; then
  echo "minecraft container is not running — nothing rotated" >&2
  exit 1
fi

podman exec minecraft rcon-cli passwordwhitelist password set "$PW" >/dev/null

# Read it back from the plugin's own store. A silent failure here would mean the
# class gets a password the server does not accept, so verify rather than assume.
CUR=$(mc-password 2>/dev/null || true)
if [ "$CUR" != "$PW" ]; then
  echo "ERROR: password did not apply — store has '${CUR:-<unreadable>}'" >&2
  exit 1
fi

echo "rotated: $PW"

if [ "$NOTIFY" = 1 ]; then
  # Do not announce while the gate is off: the password is not being asked for,
  # and a weekly message about it is pure noise. Rotation still happens, so
  # re-enabling the gate always finds a current password.
  if grep -q '^enabled=true' "$STORE" 2>/dev/null; then
    # When will this password really be replaced? The next Monday 06:00 that the
    # freshness guard will NOT skip. Getting this wrong sends a class a password
  # with an expiry date that is a week early (which is exactly what happened the
  # first time this ran on a Sunday evening).
  now=$(date +%s)
  next_rot=$(date -d 'monday 06:00' +%s 2>/dev/null || echo $((now + 604800)))
  while [ "$next_rot" -le "$now" ] || [ $((next_rot - now)) -lt $((GUARD_HOURS * 3600)) ]; do
    next_rot=$((next_rot + 604800))
  done
  expira=$(date -d "@$next_rot" '+%d/%m' 2>/dev/null || echo '?')
  msg=$(printf 'Senha do Minecraft desta semana: %s\nServidor: %s\nVale ate %s.' \
               "$PW" "${MC_SERVER_HOST:-mc.<your-domain>}" "$expira")
  if printf '%s\n' "$msg" | hermes send -t telegram -f - >/dev/null 2>&1; then
    echo "announced on telegram"
  else
    echo "warning: telegram announce failed (password IS set, read it with mc-password)" >&2
  fi
  else
    echo "gate is off — announcement suppressed (mc-gate on to re-enable)"
  fi
fi
