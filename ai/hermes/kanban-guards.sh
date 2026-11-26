#!/usr/bin/env bash
# kanban-guards.sh — apply safety defaults to kanban tasks that lack them.
#
# WHY: `enforce_max_runtime()` in hermes_cli/kanban_db_dispatch.py terminates a
# worker whose per-task `max_runtime_seconds` has elapsed — SIGTERM, short grace,
# SIGKILL, emits `timed_out`. But it filters on
#
#     WHERE t.status = 'running' AND t.max_runtime_seconds IS NOT NULL
#
# and nothing sets that column. Measured: 0 of 10 tasks had it. So the terminator
# has always existed and has never once fired, which is why an `architect` worker
# ran 4h36m on a plan review holding the only GPU slot.
#
# The orchestrator *can* pass --max-runtime per card, but that is a promise the
# model has to keep. This is the guarantee: whatever creates the card, a cap
# exists by the next timer tick.
set -uo pipefail

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=fleet.conf
[ -f "$HERE/fleet.conf" ] && . "$HERE/fleet.conf"
DEFAULT="${KANBAN_DEFAULT_MAX_RUNTIME:-7200}"

python3 - "$DEFAULT" <<'PY'
import sqlite3, sys, time, os

default = int(sys.argv[1])
db = os.path.expanduser("~/.hermes/kanban.db")
if not os.path.exists(db):
    sys.exit(0)

c = sqlite3.connect(db, timeout=10)
# Only cards that can still be worked. `done`/`archived` need no cap, and setting
# one on them would be noise. `blocked` is INCLUDED on purpose: a blocked card can
# be unblocked and dispatched, and it would then run unbounded.
rows = c.execute(
    "SELECT id, status, COALESCE(assignee,'-'), COALESCE(max_runtime_seconds,0) "
    "FROM tasks WHERE status NOT IN ('done','archived') "
    "  AND (max_runtime_seconds IS NULL OR max_runtime_seconds <= 0)"
).fetchall()

if not rows:
    print("  all active tasks already capped")
    sys.exit(0)

c.executemany(
    "UPDATE tasks SET max_runtime_seconds = ? WHERE id = ?",
    [(default, r[0]) for r in rows],
)
c.commit()
print(f"  capped {len(rows)} task(s) at {default}s ({default//3600}h{default%3600//60:02d}m):")
for tid, st, who, _ in rows:
    print(f"    {tid}  {st:<8} {who}")
c.close()
PY
