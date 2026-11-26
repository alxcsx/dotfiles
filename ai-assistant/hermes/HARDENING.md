# HARDENING.md — why the fleet fails, and what makes it stop failing

Written 2026-11-07 after the `t_35165ee8` crash loop. Every claim below is from a
command run on this box; the `file:line` refs are to
`~/.hermes/hermes-agent` (a clean git checkout) and `~/dotfiles/ai-assistant/hermes`.

---

## 1. The actual failure, traced end to end

**Card** `t_35165ee8` — "Analyze: ExoForge system (projetao_mvp)", assignee
`architect`, `skills: ["architect"]`.

| t | what |
|---|---|
| 19:42 | orchestrator creates the card. `skills: ["architect"]` |
| 19:43 | dispatcher claims it, spawns worker, passes `--skills architect` |
| 19:44 | worker exits 1 before its first turn: `Error: Unknown skill(s): architect` |
| 19:44 | retry #2 — same spawn, same argv, same crash |
| 19:45 | circuit breaker trips at 2 consecutive failures → `blocked` |
| 19:58 | orchestrator comments: *"I will now verify the issue myself…"* — and cannot. It never ran again. |

`architect` is a **profile**, not a skill. Skills are leaves of
`~/.hermes/skills/<category>/<name>/SKILL.md`; there is no `skills/architect`, so
`--skills architect` is unresolvable and the worker dies at startup.

**That is the only crash.** Nothing was broken in `architect`: it has
`terminal`, `file`, `code_execution` (verified: `hermes -p architect tools list`).
Had the card carried `skills: []` it would have run.

### Three defects, none of them the skill name

**D1 — validation at the wrong layer.**
`hermes_cli/kanban_db.py:1144 _normalize_task_skills()` rejects
`KNOWN_TOOLSET_NAMES` (so `skills=["web"]` fails loudly at creation) and refuses
comma-joined strings. It never checks the skills tree. A profile name, a
category, or a typo all pass through and land in `tasks.skills`, and the failure
is deferred from *creation* (instant, no cost, correctable by the creator) to
*spawn* (60 s, one claim burned, retried, then a blocked card that needs a human).

**D2 — detection without repair.**
`fleet-check.py:353-375` already detects exactly this, and printed
`t_35165ee8 names skill(s) ['architect'] which do not exist. The worker dies at
startup on every retry.` It is a **reporter**: it has no remediation, and the
report goes to Telegram, which is where the human is expected to run the fix.
Every check in that file has this shape.

**D3 — the repair path does not exist.**
`hermes kanban edit` supports `--title --body --priority --result --summary
--metadata`. There is **no** `--skills`, `--workspace`, `--assignee` (that is
`reassign`) or `--status`. An agent that *did* notice the bad card still had no
CLI verb to fix it. (Today's fix was a direct `UPDATE tasks SET skills = NULL`
— a documented workaround, not a tool.)

### Why the orchestrator said something false instead of something true

The orchestrator is the profile that coordinates everything, and it is the one
profile with no hands:

| profile | terminal | file | code_execution |
|---|---|---|---|
| orchestrator | ✗ | ✗ | ✗ |
| architect | ✓ | ✓ | ✓ |
| dev | ✓ | ✓ | ✓ |
| research | ✓ | ✓ | ✓ |

A coordinator holding only `kanban`, `memory`, `todo`, `delegation`,
`session_search`, `web` can observe *the board* and nothing about the machine.
Asked why a card failed, it has exactly one available move: write a paragraph in
the register of a fix. That is the mechanism behind the "five agent-authored
diagnoses, all confidently wrong" in AGENTS.md — **not** a model defect. Give a
model a narrative-shaped tool surface and it will narrate. The rules in SOUL.md
tell it to use `fleet-check` output as truth; it cannot run `fleet-check`.

---

## 2. The rest of the fragility, ranked by what it costs

| # | failure mode | evidence | cost |
|---|---|---|---|
| F1 | Bad `skills` value kills the worker at spawn (D1+D2+D3) | this card | a card dies 2× then needs a human |
| F2 | Stale-stream **latch** — after 5 starved streams a session fails every turn in 0.1 s, forever | session sat 2 h on 2026-10-18 | the flagship channel goes silently dead |
| F3 | Telegram transport is the weakest link *and* the only channel to you | ~40 `ConnectTimeout`/`ConnectError` in 3 days, one `updater.stop()` fatal that rebuilt the adapter | you cannot be told about F2 because F3 |
| F4 | No fallback provider. One model, one GPU, one slot (`parallel=1`), no degraded mode | `fleet.conf` | any stall stops the whole fleet |
| F5 | Detection is after the fact: 15-min `fleet-check` vs a 2-attempt breaker | `fleet-check.timer`, `KANBAN_FAILURE_LIMIT=2` | a poison card is found only once it is already blocked |
| F6 | Agents cannot escalate. `tg-approve.py` exists in dotfiles but **is not installed** (`/usr/local/sbin/tg-approve` and `/etc/tg-approve` both missing) | `ls` | every root-level fix needs the human in the loop, which is the thing you want less of |
| F7 | A worker that "finishes" wrong self-certifies (`kanban_complete`) | `KANBAN_REVIEW_DISPATCH=false` (correctly) | no mechanical check that the work exists |
| F8 | Two dead timers show as `failed` units (`mc-rotate-password.timer`, `mc-sync-verified.timer`) | `systemctl --user list-units --state=failed` | 2 lines of permanent noise that trains you to ignore `failed` |

---

## 3. The fix, in the order that pays

### Phase 0 — one hour, ~60 lines, kills F1/F5 (do first)

**0.1 Validate skills where they are created.** In
`hermes_cli/kanban_db.py:_normalize_task_skills`, after the toolset check, resolve
each name against the same tree `fleet-check.py:_valid_skill_names()` uses
(`~/.hermes/skills/*/*/SKILL.md` plus each profile's `skills/`), and raise with
the nearest-name suggestion. ~20 lines. This is an upstream patch: record it as
such, because `git -C ~/.hermes/hermes-agent pull` will conflict.
*Alternative if you want zero local patches:* validate in `k` and in the
`kanban_create` tool wrapper. Weaker — it misses cron- and dashboard-created
cards.

**0.2 Make `fleet-check` repair the conditions it can prove.**
Turn the skill check into `UPDATE tasks SET skills = NULL` + a comment on the
card recording what was removed and why. Same for the `scratch`-workspace check
on an implementation card (rewrite to the last run's workspace path, or block
with `--kind capability`). Print the repair in the notification as
`fixed:` rather than `problem:`. Detection that never repairs is a pager, and
this box has one person.

**0.3 `hermes kanban edit --skills/--assignee`.** Two flags over `reassign` and
the existing UPDATE path. Without them, D3 stays: every agent that finds a bad
card still needs sqlite.

Verification: create a card with `--skills architect` → creation fails with a
message naming the category; `fleet-check` run twice → the second is silent.

### Phase 1 — give the coordinator hands (this is your Telegram request)

**1.1 Enable on `orchestrator`:** `terminal`, `file`, `code_execution`.
`browser` and `computer_use` stay off (vision is dead; `computer_use` on a
headless box is a trap).

**1.2 Write `~/.hermes/skills/devops/fleet-maintenance/SKILL.md`** — the runbook
the hands are supposed to follow. It must contain the *commands*, not advice:
where `fleet-check`/`fleet-drift`/`fleet-apply` are, that `k` addresses cards,
that `hermes kanban edit` cannot set skills, that `kanban reclaim` respawns
(a `block` stops), that `sudo` needs a password, that restarts are `--user`.
Cross-link it from the orchestrator SOUL as the first thing to load on "why did
X fail".

**1.3 Bound the new power with three rails, written into the skill and the SOUL:**

- **Never restart the gateway from inside it.** `systemctl --user restart
  hermes-gateway` during a turn kills its own session mid-write. Always:
  `systemd-run --user --on-active=5s systemctl --user restart hermes-gateway`.
- **Every change to `~/dotfiles` is one git commit before the next change**, so
  a bad edit is `git revert` and not a lost afternoon. `~/dotfiles` is already
  in the restic path; `~/.hermes` is too — `dotfiles` is the cheap one.
- **Verdicts require output.** Any sentence of the form "X is broken / healthy"
  must carry the command that showed it, in the same message. This is the
  existing rule in AGENTS.md; what is new is that it becomes *checkable* once the
  agent can run things.

**1.4 Measure the tax before keeping it.** Tool schemas cost prompt on every
turn, and prompt is the real currency here:
```
hermes -p orchestrator chat -q 'Reply with the single word: ok' --oneshot -Q
journalctl --user -u llamacpp-daemon -n 200 | grep 'stop processing: n_tokens'
```
`terminal`+`file`+`code_execution` are ~3-4 k tokens of schema on a baseline of
~24 k. If it exceeds ~28 k, keep `terminal` only and drop `file` (the terminal
can `sed`/`grep`/`cat`).

**1.5 Fallback model on the orchestrator** (kills F4's worst case): if the
30B is heat-soaked, `qwen3.5:9B` at 22 tok/s still answers; a `remote` profile
already exists for the egress path. A coordinator that cannot respond is worth
less than a slow one.

### Phase 2 — the latch (F2), the highest-severity silent failure

The counter is `_consecutive_stale_streams`, reset only by a stream that starts.
Five starvations latch the session permanently. Two lines of defence, both cheap:

- **A `SessionStart`-equivalent guard** is not available for this; use
  `fleet-check`: read each profile's `state.db` for sessions whose last N turns
  are all the 362-char apology / all sub-1 s, and delete them
  (`hermes sessions delete <id>`), then tell you which session and profile.
- **Lower the odds:** already done via `LOCAL_STREAM_STALE_TIMEOUT=1800` and
  `COMPRESSION_THRESHOLD_TOKENS=40000`. Keep them.

### Phase 3 — close F3 and F6

- **F3:** `hermes-gateway` already tolerates reconnects; what it does not have is
  a **second** delivery path for "the gateway is down". `fleet-tg-send.py` is a
  direct API call, independent of the gateway — make `fleet-check` use it for
  anything it classifies as critical, and add a `fleet-check` clause for
  *"gateway has not logged a successful getUpdates in N minutes"*. You currently
  learn the gateway is dead by noticing silence.
- **F6:** install `tg-approve` (needs root, so it is a command block for you, not
  something an agent can do — and that is the point):

  ```
  sudo install -d -m 750 /etc/tg-approve
  sudo sh -c 'umask 077; printf %s "<BOT_TOKEN>" > /etc/tg-approve/token; printf %s "<CHAT_ID>" > /etc/tg-approve/chat_id'
  sudo install -m 755 -o root -g root ~/dotfiles/ai-assistant/hermes/tg-approve.py /usr/local/sbin/tg-approve
  echo 'alex ALL=(root) NOPASSWD: /usr/local/sbin/tg-approve' | sudo tee /etc/sudoers.d/tg-approve
  sudo chmod 440 /etc/sudoers.d/tg-approve && sudo visudo -c
  sudo -n tg-approve --self-test
  ```
  Then an agent's escalation is `sudo tg-approve systemd-unit restart docker.service`
  → you tap Approve → it runs. Fail-closed by design, verb-whitelisted, one argv,
  one chat, one deadline. This is the difference between "the agent asked me to
  paste a command" and "the agent asked me for one tap".

### Phase 4 — stop the class, not the instance

- **`max_retries=1` on any card whose failure is a startup error.** A
  `skills`/`workspace`/`assignee` failure is deterministic: retrying re-runs the
  same argv. The breaker's job is to catch *non-deterministic* failure.
- **Ban unbounded audit cards.** `t_35165ee8` was "audit 9 domains, return 1-50
  items" on `scratch` with a 2 h cap. That is a runaway generator — the same
  shape as the 4 h 36 m and 2 h 37 m runs. Replace with N enumerated cards, each
  with a stated output file.
- **Two dead timers** (F8): `systemctl --user reset-failed
  mc-rotate-password.timer mc-sync-verified.timer` and remove the unit files from
  dotfiles, or the `failed` state keeps training you to ignore the colour.

---

## 4. What I am deliberately not doing

- **Not patching `~/.hermes/hermes-agent` today.** A local edit to
  `kanban_db.py` blocks `git pull` and survives no reinstall. Phase 0.1 needs a
  decision (patch vs. wrapper) before anyone writes it.
- **Not turning on agent review.** `KANBAN_REVIEW_DISPATCH=false` is correct on a
  one-GPU box and the evidence (t_c58bc0d2) is unambiguous.
- **Not adding a metrics/tracing stack.** There is no second machine and no
  budget for Prometheus + Grafana; `fleet-check`, `journalctl` and
  `llm-bench.py` already answer the questions that get asked.
- **Not enabling `browser` or `computer_use` for anyone.** No VLM exists here, so
  a browser agent cannot see what it did.

## 5. Unblocked-today checklist

1. `preset skills` validation (Phase 0.1) — the crash class.
2. `fleet-check` repairs instead of nags (0.2) — turns the pager into a fixer.
3. `hermes kanban edit --skills` (0.3) — removes the sqlite workaround.
4. orchestrator gets `terminal` (1.1) + `fleet-maintenance` skill (1.2) +
   the three rails (1.3).
5. Measure the prompt delta (1.4); keep or roll back on the number.
6. `tg-approve` install block (F6) — you run it once.
