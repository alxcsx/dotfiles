# Agent roster and budget rules

Shared by every agent (omp, claude, agy, copilot). Find yourself in the table.

| Agent | Budget | Use for |
|---|---|---|
| `omp` | 5h/weekly/monthly limits; free models when out | paid: exploring, implementing, tests, refactors. Free models (weaker than haiku): trivial edits and lookups only |
| `agy` | weekly quota | architecture, second opinions |
| `claude` | 5h windows, very tight | last resort: planning, hard debugging, reviewing diffs |
| `copilot` | 200 credits/month | last resort: small cross-checks |

## Rules

Small quotas everywhere: get the work done with the fewest tokens. The user
tests and troubleshoots; do not spend credits on it.

- Cheapest first: `omp`, then `agy`, then `claude`/`copilot`. Check `quota`
  before delegating; skip agents marked low or out.
- Plan first for non-trivial work: a short plan (a few lines) with what to
  build and how it will be checked; do not iterate on it or get it reviewed.
  Small or clear tasks need no plan.
- Write simple test cases alongside the code (a few focused ones, no big
  suites). Do not run them or debug at length while working; do only a quick
  sanity check (syntax, build, linter) and hand over.
- Run the tests and do the review only before a push (or when asked): run the
  tests, review the diff once, with a different model family than the author.
  Do not delegate reviews of work in progress.
- Expensive agents never read the repo broadly or write bulk code; hand that to
  `omp`.
- Keep context small: one task per session (`/clear` between tasks), and do not
  paste logs or file dumps into a session; send a path.
- Start from `.agents/INDEX.md` (run `agents-index` to refresh it) and open
  only the handoff or task you need; do not read `.agents/` wholesale.
- Reports: at most 10 lines, `file:line` refs, what changed, what to test.
  Longer goes in `.agents/handoff/<topic>.md`; send the path.

## Delegating (only when `HC_TERMINAL_ID` is set)

- `ask <agent> "<task>"` is the default; it delegates in that agent's Herdr terminal; the answer
  arrives as `REPORT(<agent>): ...`. When a task came from another agent,
  finish with the reply command it gave.
- `ask <agent>:<model> ...` targets (or starts) a pane for that model, e.g.
  `ask omp:deepseek-v4-pro`, `ask agy:argon`. Start several up front with
  `orch omp:deepseek-v4.1-flash omp:deepseek-v4-pro agy:hydrogen agy:argon`.
- `ask <agent> --spec <file.json>` is optional, for tasks that need exact
  acceptance commands (`agents/task.schema.json`).
- `ask --headless <agent> "<task>"` is a one-shot run (`omp`, `claude`, `copilot`).
- `quota` shows each agent's status (omp live from `omp usage`); `quota set <agent> ok|low|out [until]`.
- One helper at a time; helpers never start more agents. Read-only unless the
  task asks for edits.

## agy `/teamwork`

Prefer Gemini models (`gemini-4-*`, `gemini-pro-orchestrator-*`). agy's
`claude-*` and `gpt-oss-*` models use a separate, smaller agy quota (they do not
drain the claude/copilot quota), so use them when Gemini is out or when a
different model family is wanted. Herdr shows
agy idle while subagents run, so wait for `.agents/TEAMWORK_DONE.json` or the
`TEAMWORK_DONE` reply, or check `hc read agy --lines 30`.
