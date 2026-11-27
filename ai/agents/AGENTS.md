# Agent roster and budget rules

Shared by every agent (omp, claude, agy, copilot, codex, feynman). Find yourself in the table.

| Agent | Budget | Use for |
|---|---|---|
| `omp` | 5h/weekly/monthly limits; free models when out | paid: exploring, implementing, tests, refactors. Free models (weaker than haiku): trivial edits and lookups only |
| `agy` | weekly quota | architecture, second opinions, reviews |
| `claude` | 5h windows, very tight | last resort: planning, hard debugging, reviewing diffs |
| `copilot` | 200 credits/month | last resort: small cross-checks |
| `codex` | expanded quota | preferred: complex implementation, debugging, repo-wide refactors, and final diff review |
| `feynman` | shares `omp` (`opencode-go`) quota | literature search, paper audits, research synthesis (no `:model` or `--effort` CLI flag) |

## Rules

Small quotas everywhere: get the work done with the fewest tokens. The user
tests and troubleshoots; do not spend credits on it.

- Use `omp` for small, well-scoped work. Prefer `codex` for complex implementation,
  debugging, or refactors; use `agy` for architecture and independent review. Check
  `agent-quota` before delegating: prioritize `prefer-now`, avoid `wait`, and refresh
  provider status for `refresh` before assigning work.
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
- Never run `sudo` directly. Warn the user at the start of the task whenever
  elevation will be needed (or pass `ask --sudo "<reason>"` / set `needs_sudo`
  in `--spec`). Submit one reviewed, idempotent script with
  `privileged-request run "reason and rollback"`; macOS and desktop Linux require
  an OS authentication dialog, while headless Linux queues it for the operator.
- Start from `.agents/INDEX.md` (run `agents-index` to refresh it) and open
  only the handoff or task you need; do not read `.agents/` wholesale.
- Reports: at most 10 lines, `file:line` refs, what changed, what to test.
  Longer goes in `.agents/handoff/<topic>.md`; send the path.

## Model routing

| Model | Use for / Notes |
|---|---|
| `omp:deepseek-v4.1-flash` | default workhorse: implementation, scripts, infra, simple tests, refactors |
| `omp:deepseek-v4-pro` | hard implementation tasks (performance tuning, complex analysis) |
| `omp:hy4-flash-free` | short, well-scoped tasks (formatting, lookups, small edits) |
| `omp:hy4-flash` | experimental, cheap; test only on small tasks |
| `omp:longcat-2.5` | search/triage only; avoid prose generation (reports of loops and Chinese output). For long text use `deepseek-v4.1-flash`/`v4-pro` + human review |
| `agy:neon`, `agy:hydrogen`, `agy:argon` | architecture, second opinions, reviews (`hydrogen` for technical/statistical/final diff review; `neon` for prose) |
| `claude` / `copilot` | last resort: single pre-push diff review; `copilot` also for small cross-checks (e.g., verifying URLs/references) |
| `codex` (`codex exec`) | preferred for complex implementation, hard debugging, and repo-wide refactors; also use for final review when an independent OpenAI-family perspective is useful |

Avoid `omp:beam-free` (400 errors, corrupted paths), `omp:mimo-v2.6-flash`, and `omp:glm-5.3-flash` (poor tool calling). Weak/free models never make design decisions or write conclusions; they only execute well-scoped tasks.

## Delegating (only when `HC_TERMINAL_ID` is set)

- `ask [--effort <level>] <agent[:model]> <task...>` is the default; it delegates in that agent's Herdr terminal; the answer
  arrives as `REPORT(<agent>): ...`. When a task came from another agent,
  finish with the reply command it gave. `--effort` maps to each agent's reasoning/thinking flag (`omp`, `claude`, `agy`, `copilot`, `codex`) and `agy` short names (`neon`, `hydrogen`, `argon`, `carbon`, `flash`) resolve to full `agy models` IDs (e.g., `gemini-4-argon-medium`).
- `ask <agent>:<model> ...` targets (or starts) a pane for that model, e.g.
  `ask omp:deepseek-v4-pro`, `ask agy:argon`. Start several up front with
  `orch omp:deepseek-v4.1-flash omp:deepseek-v4-pro agy:hydrogen agy:argon`.
- `ask <agent> --spec <file.json>` is optional, for tasks that need exact
  acceptance commands (`agents/task.schema.json`).
- Permission review: `codex` and `copilot` run sandboxed with `agent-gate`.
  When a delegated worker requests a sensitive action (including `git push`,
  destructive git ops, recursive `rm`, or out-of-spec writes), the orchestrator
  receives `PERM_REQUEST(<id>) ...`. Review it and run `ask --allow <id>` or
  `ask --deny <id> "<reason>"` (`ask --pending` lists open requests). `sudo`
  cannot be approved by an orchestrator and always requires `privileged-request`.
- `ask --headless <agent> "<task>"` is a one-shot run (`omp`, `claude`, `copilot`).
- `agent-quota` shows status, a routing recommendation, and known reset countdowns.
  OMP is live from `omp usage`. For other subscription agents, copy the reset timestamp
  shown by the provider: `agent-quota set claude low 2026-11-28T02:00:00-03:00`.
  Do not infer a weekly reset from transcript token counts.
- One helper at a time; helpers never start more agents. Read-only unless the
  task asks for edits.

## agy `/teamwork`

Prefer Gemini models (`gemini-4-*`, `gemini-pro-orchestrator-*`). agy's
`claude-*` and `gpt-oss-*` models use a separate, smaller agy quota (they do not
drain the claude/copilot quota), so use them when Gemini is out or when a
different model family is wanted. Herdr shows
agy idle while subagents run, so wait for `.agents/TEAMWORK_DONE.json` or the
`TEAMWORK_DONE` reply, or check `hc read agy --lines 30`.
