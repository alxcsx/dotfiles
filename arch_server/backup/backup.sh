#!/usr/bin/env bash
# backup.sh — snapshot everything irreplaceable, to Google Drive via rclone.
#
# WHY restic and not `rclone sync`: sync mirrors, so a local deletion propagates
# and you discover it only when you need the file. restic takes immutable
# snapshots — deleting locally costs nothing until a snapshot expires, and the
# repository is encrypted client-side so Drive never holds plaintext.
#
# WHAT IS AND IS NOT IN HERE
#   included : the board, every session, all 8 profile configs, memories, skills,
#              SOUL.md files, ~/.hermes/.env, dotfiles, the model preset.
#              These are the things that cannot be reconstructed.
#   excluded : *.gguf models (re-downloadable), the hermes-agent git checkout and
#              ~/.hermes/tools (both re-installable). Cuts the job from ~3.6 GB
#              to a few MB, which is what makes a daily run cheap.
#
# NOTE ON ~/.hermes/.env: it holds the Telegram bot token, which grants shell
# access to this machine. It is included because a restore without it is not a
# restore — but it is only safe because the restic repo is encrypted. Guard the
# restic password accordingly.
set -euo pipefail

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Machine-local overrides, read once. Put the destination here so it is set in one
# place rather than passed on every invocation.
#   RESTIC_REPOSITORY=rclone:gdrive:Backups/derby
BACKUP_CONF="${BACKUP_CONF:-$HOME/.config/restic/backup.conf}"
# shellcheck source=/dev/null
[ -f "$BACKUP_CONF" ] && . "$BACKUP_CONF"

# The repository is a PATH INSIDE the rclone remote:
#     rclone:<remote>:<folder>/<subfolder>
# rclone creates the folders on first write, so nothing has to exist up front — but
# `restic init` binds to the final path, so choose it BEFORE the first backup. Moving
# the repo later means copying it, not editing this line.
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-rclone:gdrive:derby-backup}"
export RESTIC_REPOSITORY
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-$HOME/.config/restic/password}"

[ -f "$RESTIC_PASSWORD_FILE" ] || {
  echo "missing restic password file: $RESTIC_PASSWORD_FILE" >&2
  echo "create it with:  install -Dm600 /dev/null $RESTIC_PASSWORD_FILE  # then write a long passphrase" >&2
  exit 2
}

command -v restic >/dev/null || { echo "restic not installed" >&2; exit 2; }
command -v rclone >/dev/null || { echo "rclone not installed" >&2; exit 2; }

# First run initialises the repository rather than failing.
if ! restic snapshots >/dev/null 2>&1; then
  echo "initialising restic repository at $RESTIC_REPOSITORY"
  restic init
fi

# --files-from keeps the include list readable and adding a path a one-line diff.
# services/ was added 2026-10-18: it holds the Minecraft world, the AuthMe account
# database and the Quadlet-adjacent data. Without it a restore brings back
# ~/.hermes and ~/dotfiles but not the game world or the container definitions.
#
# The three root-level docs were added the same day, after PLAN.md was truncated
# by a bad script edit and turned out to have **no copy anywhere** — not here, not
# in any snapshot, no btrfs snapshots on this machine. AGENTS.md sat outside the
# backup list too, one careless write from the same fate.
INCLUDE=$(mktemp)
cat >"$INCLUDE" <<EOF
$HOME/.hermes
$HOME/dotfiles
$HOME/services
$HOME/PLAN.md
$HOME/AGENTS.md
$HOME/README.md
$HOME/.config/containers/systemd
$HOME/.config/cloudflare-ddns
$HOME/.config/egress-proxy
$HOME/.config/llamacpp/models-preset.ini
$HOME/.config/llama.cpp
EOF

echo "backing up…"
# The minecraft server jar and plugin jars are deliberately NOT backed up: they
# are re-fetched on start (VERSION=LATEST, MODRINTH_PROJECTS). Excluding them is
# the difference between ~9 MB and ~90 MB per snapshot. Keep excludes as bare
# lines inside this command — a comment in the middle of a backslash-continued
# command silently terminates it (that bug shipped once and the excludes after
# the comment never applied).
restic backup \
  --files-from "$INCLUDE" \
  --exclude '*.gguf' \
  --exclude '*.safetensors' \
  --exclude "$HOME/.hermes/hermes-agent" \
  --exclude "$HOME/.hermes/tools" \
  --exclude "$HOME/.hermes/cache" \
  --exclude "$HOME/.hermes/installs" \
  --exclude "$HOME/.hermes/audio_cache" \
  --exclude "$HOME/.hermes/image_cache" \
  --exclude "$HOME/.hermes/backups" \
  --exclude "$HOME/.hermes/kanban/workspaces" \
  --exclude "$HOME/services/minecraft/data/libraries" \
  --exclude "$HOME/services/minecraft/data/cache" \
  --exclude "$HOME/services/minecraft/data/versions" \
  --exclude "$HOME/services/minecraft/data/logs" \
  --exclude "$HOME/services/minecraft/data/*.jar" \
  --exclude "$HOME/services/minecraft/data/plugins/*.jar" \
  --exclude "$HOME/services/minecraft/data/plugins/*/libs" \
  --tag derby
rm -f "$INCLUDE"

# Retention. Without this the repository grows forever and Drive fills.
#
# `restic unlock` BEFORE it, on purpose: an aborted run (Ctrl-C, a reboot, the
# safety timer firing) leaves a non-exclusive lock behind. `backup` tolerates that
# lock, but `forget --prune` needs an EXCLUSIVE one and dies with exit 11 — so the
# unit reports FAILED even though the snapshot was written, and from then on every
# run fails the same way while snapshots pile up unpruned. Measured 2026-10-19:
# snapshot 04:09:40 written, exit 11 at 04:10:15, one stale lock from the 22:31
# manual run. Plain `unlock` (not --remove-all) only drops locks older than 30
# minutes, so it cannot stomp a concurrent backup.
restic unlock
restic forget \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
  --prune

echo
echo "snapshots now held:"
restic snapshots --compact | tail -12

# Verification. A backup you have never read back is a hypothesis, not a backup.
# Weekly-ish integrity check of repository metadata + a sample of pack data.
if [ "${RESTIC_VERIFY:-0}" = "1" ]; then
  echo
  echo "verifying (sample)…"
  restic check --read-data-subset=5%
fi
