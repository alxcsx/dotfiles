#!/usr/bin/env bash
# docs-snapshot — version the hand-maintained docs so no single bad write is fatal.
#
# Why this exists: PLAN.md was truncated to 0 bytes by one faulty script edit and
# turned out to have NO copy anywhere — not in the nightly restic backup (it was
# outside the include list), no btrfs snapshots, nothing. A daily backup would
# still have lost up to 24 h of edits. This commits a copy of each document to a
# local git repo whenever its contents change, so `git log`/`git checkout` can
# undo any single mistake within a minute.
#
# Deliberately NOT a public repo: AGENTS.md and PLAN.md describe this machine.
# Local only, prompt every run, nothing pushed.
#
#   docs-snapshot            commit changed docs
#   docs-snapshot --status   show what differs, change nothing
set -euo pipefail

DOCS=(PLAN.md AGENTS.md README.md)
REPO="$HOME/.local/share/doc-history"

[ -d "$REPO/.git" ] || { mkdir -p "$REPO"; git -C "$REPO" init -q; }

changed=0
for doc in "${DOCS[@]}"; do
  src="$HOME/$doc"
  [ -f "$src" ] || continue
  dst="$REPO/$doc"
  if ! cmp -s "$src" "$dst"; then
    if [ "${1:-}" = "--status" ]; then
      echo "changed: $doc ($(wc -c <"$src") bytes now, $(wc -c <"$dst" 2>/dev/null || echo 0) in history)"
    fi
    cp -p "$src" "$dst"
    changed=$((changed + 1))
  fi
done

if [ "${1:-}" = "--status" ]; then
  [ "$changed" -eq 0 ] && echo "all docs match history"
  exit 0
fi

if [ "$changed" -eq 0 ]; then
  exit 0
fi

git -C "$REPO" add -A
git -C "$REPO" -c user.name=docs-snapshot -c user.email=docs@derby \
  commit -q -m "snapshot $(date '+%Y-%m-%d %H:%M') — ${changed} doc(s) changed"
echo "committed $changed doc(s) to $REPO"

# Keep the history bounded: the docs are text, but a runaway editor can bloat it.
git -C "$REPO" gc --auto --quiet 2>/dev/null || true
