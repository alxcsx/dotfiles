# Sanctioned patches to `~/.hermes/hermes-agent`

That directory is a **git checkout of upstream** (`hermes update` = `git pull`), so a
local edit is not free: it will conflict on the next update. These are the two we
accept, and why each one cannot live outside the checkout.

Re-apply after an update conflict:

```bash
cd ~/.hermes/hermes-agent && git apply --3way ~/dotfiles/ai/hermes/patches/*.patch
```

Verify (should print one rejection and two edits):

```bash
hermes kanban --board tmpcheck create x --assignee dev --skill architect   # rejected
hermes kanban --board tmpcheck edit <id> --clear-skills                    # accepted
hermes kanban boards remove tmpcheck
```

## 0001 — kanban skill validation + the `edit --skill` repair verb

Two halves of one bug, both in `hermes_cli/kanban_db.py`:

1. `_normalize_task_skills()` rejected **toolset** names (`web`, `browser`) but never
   checked the skills tree, so a CATEGORY (`creative`) or a PROFILE (`architect`)
   sailed through and landed in `tasks.skills`. The worker then failed at **spawn**
   with `Unknown skill(s): architect` — after a claim, twice, and the card was
   parked for a human. Measured on `t_35165ee8`, 2026-11-06.
2. `edit_task()` had no way to change `skills` and the CLI had no flag, so a card
   that already carried a bad name could not be repaired at all except by raw SQL.

Cannot live outside the checkout: both are inside `kanban_db.py`, which owns the
schema. A wrapper around `hermes kanban create` would miss the agent tool, the
dashboard and cron, which are the paths that actually create cards.

Failure mode of the patch itself: `get_all_skills_dirs()` failing (import error,
missing config) returns `None` and validation is **skipped** — card creation never
fails because of the probe. A skills tree that is temporarily empty does the same.
That is the intended direction: reject loudly when we can see the tree, never block
on not being able to.

## Deliberately not patched

- `pre_tool_call` hooks never firing (upstream bug, v0.21.7) — the workaround is
  capability, not a hook.
- Telegram `reply_prefix` ignored — attribution uses the emoji tags in each soul.
- `_consecutive_stale_streams` latch — the fix is detection (`fleet-check` reads
  the journal), not a patch; a patched counter would be lost on the next update.
