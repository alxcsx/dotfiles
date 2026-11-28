#!/usr/bin/env python3
"""fleet-check — one health surface for the whole agent fleet.

Why this exists: every failure found during setup was found by reading journals
by hand, never by the system reporting it. `pre_tool_call` hooks that never
fire, Telegram `reply_prefix` that is a no-op, `--parallel 4` silently capping
every request at 16k, an invalid skill killing workers at startup, `scratch`
workspaces making review impossible, `skipped_nonspawnable` notifying nobody.
Six silent failures; the first watchdog covered two of them.

A watchdog per bug scales with the bugs you have already found. This is the
general surface: services, model reachability, disk, and the board — printed
only when something is wrong, so the timer can pipe stdout straight to Telegram
and stay quiet the rest of the time.

Exit code is always 0. A health checker that fails must not itself page you.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request

HERMES = "hermes"
MODEL_URL = "http://127.0.0.1:58000/v1/models"
EXPECTED_MODEL = "qwen3.6-30b-a3b"
SERVICES = ["llamacpp-daemon", "egress-proxy", "hermes-gateway", "hermes-dashboard",
            "minecraft", "file-drop"]
DISK_MIN_FREE_GB = 50

# Board thresholds. A card the dispatcher should have claimed spawns within one
# 60s tick, so `ready` this long is never mere slowness.
READY_STALE_S = 30 * 60
REVIEW_STALE_S = 6 * 3600
BLOCKED_STALE_S = 6 * 3600
# A `kind=capability` block is explicitly waiting on a HUMAN to install something.
# 6h of silence on that is the wrong trade — the whole point of the block is to ask.
CAPABILITY_STALE_S = 30 * 60


# ── helpers ──────────────────────────────────────────────────────────────────
def _sh(*args: str, timeout: int = 120) -> tuple[int, str]:
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout
    except Exception:
        return 1, ""


def _json(*args: str):
    rc, out = _sh(*args)
    if rc != 0:
        return None
    try:
        return json.loads(out)
    except Exception:
        return None


def _age(ts) -> float:
    try:
        return time.time() - float(ts)
    except (TypeError, ValueError):
        return 0.0


def _human(seconds: float) -> str:
    m = int(seconds // 60)
    if m < 60:
        return f"{m}m"
    if m < 60 * 24:
        return f"{m // 60}h{m % 60:02d}m"
    return f"{m // (60 * 24)}d"


def _valid_skill_names() -> set[str]:
    """Skill names, discovered from disk.

    A skill is a directory containing SKILL.md, and its NAME is that directory
    (`skills/<category>/<name>/SKILL.md`). Passing the CATEGORY instead is the
    natural mistake and produces `Unknown skill(s): <category>`, which kills the
    worker at init before it can report. Read from disk rather than parsed from
    `hermes skills list` so a table-format change cannot blind it.
    """
    import pathlib

    names: set[str] = set()
    home = pathlib.Path.home()
    roots = [home / ".hermes" / "skills"]
    prof = home / ".hermes" / "profiles"
    if prof.is_dir():
        roots += [p / "skills" for p in prof.iterdir() if p.is_dir()]
    for root in roots:
        if root.is_dir():
            for md in root.rglob("SKILL.md"):
                names.add(md.parent.name)
    return names


# ── checks ───────────────────────────────────────────────────────────────────
def check_services(problems: list[str]) -> None:
    down = []
    for svc in SERVICES:
        rc, out = _sh("systemctl", "--user", "is-active", svc, timeout=15)
        if out.strip() != "active":
            down.append(svc)
    if down:
        problems.append(
            f"  • service(s) not active: {', '.join(down)}\n"
            f"    `systemctl --user status <name>`"
        )


def check_serve(problems: list[str]) -> None:
    """The tailnet entrypoint, if one has been set up.

    `tailscale serve` is daemon-side config that survives reboots, but it is
    invisible when it breaks — the dashboard is fine on loopback, its unit is
    active, and only the phone cannot connect. Silent, so it gets checked.
    """
    rc, out = _sh("tailscale", "serve", "status", timeout=30)
    if rc != 0 or "https://" not in out:
        # Not configured is not a fault; a machine that never enabled Serve stays
        # quiet. Only a configured-but-dead endpoint is reported.
        return
    url = next((w for w in out.split() if w.startswith("https://")), None)
    if not url:
        return
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            code = r.status
    except urllib.error.HTTPError as e:
        code = e.code  # a 302 to /login is the healthy answer
    except Exception as exc:
        problems.append(
            f"  • tailnet entrypoint {url} is configured but unreachable "
            f"({type(exc).__name__}).\n    The dashboard may still be fine on loopback."
        )
        return
    if code >= 500:
        problems.append(f"  • tailnet entrypoint {url} returned HTTP {code}")

    # /files is the download route. A dead one is silent in the worst way: the
    # bot keeps handing out links that only it can open.
    if "/files" in "".join(l for l in out.splitlines() if "/files" in l):
        files_url = url.rstrip("/") + "/files/"
        try:
            with urllib.request.urlopen(files_url, timeout=20) as r:
                fcode = r.status
        except urllib.error.HTTPError as e:
            fcode = e.code
        except Exception as exc:
            fcode = f"{type(exc).__name__}"
        if not (isinstance(fcode, int) and 200 <= fcode < 400):
            problems.append(
                f"  • download route {files_url} is routed but answers {fcode}.\n"
                f"    Check `systemctl --user status file-drop` and `tailscale serve status`."
            )


CRON_STALE_S = 30 * 60   # a normal board-digest run takes ~4 min; 30 min is a runaway


def check_cron(problems: list[str]) -> None:
    """Cron jobs that have been running far longer than they should.

    Cron agent runs have NO wall-clock cap — `agent.gateway_timeout` is an
    *inactivity* timeout, so a job that keeps generating never trips it. One
    `board-digest` run took 2 h 37 m (37 tool calls) where a normal run takes
    ~4 min, and nothing reported it because a running job is not a failure.

    Detectable here because executions.db records started_at and finished_at.
    """
    import datetime
    import sqlite3

    db = os.path.expanduser("~/.hermes/cron/executions.db")
    if not os.path.exists(db):
        return
    try:
        conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=5)
        rows = conn.execute(
            "SELECT id, job_id, started_at FROM executions "
            "WHERE finished_at IS NULL AND started_at IS NOT NULL"
        ).fetchall()
        conn.close()
    except Exception:
        return

    now = datetime.datetime.now(datetime.timezone.utc)
    for eid, job, started in rows:
        try:
            t = datetime.datetime.fromisoformat(str(started))
            if t.tzinfo is None:
                t = t.replace(tzinfo=datetime.timezone.utc)
            mins = (now - t).total_seconds() / 60
        except Exception:
            continue
        if mins >= CRON_STALE_S / 60:
            problems.append(
                f"  • cron job `{job}` has been running {mins:.0f} min (execution {eid[:8]}).\n"
                f"    Cron runs have no wall-clock cap — a normal digest takes ~4 min.\n"
                f"    `hermes cron runs {job}` · `hermes cron pause {job}`"
            )


def check_failed_units(problems: list[str]) -> None:
    """Any failed user unit, not just the ones we remembered to list.

    The timers added on 2026-10-18 (cloudflare-ddns, mc-rotate-password,
    mc-sync-verified, docs-snapshot) are oneshot services: a failing one sits in
    `failed` state until someone looks. Listing them individually would mean this
    file needs editing every time a unit is added, so ask systemd instead.
    """
    rc, out = _sh("systemctl", "--user", "--failed", "--no-legend", "--plain", timeout=20)
    failed = [ln.split()[0] for ln in out.splitlines()
              if ln.strip() and ln.split()[0].endswith(".service")]
    if failed:
        problems.append(
            f"  • failed user unit(s): {', '.join(failed)}\n"
            f"    `systemctl --user status <name>` · `journalctl --user -u <name> -n 30`"
        )


def check_channel(problems: list[str]) -> None:
    """The gateway's own two silent ways to be dead.

    1. THE STALE LATCH. `agent._consecutive_stale_streams` is in-memory only —
       nothing on disk records it — and it latches a session permanently past
       HERMES_STREAM_STALE_GIVEUP (5). After that every turn raises in 0.1 s with
       no network attempt, so the only symptom is an apology that appears
       instantly. Observed 2026-10-18: the orchestrator's Telegram session sat
       latched for two hours while its log filled with "Provider has been
       unresponsive … 5 consecutive stale attempts". The journal is the only
       surviving trace of it, so read the journal.

    2. A DEGRADED TELEGRAM PATH. On 2026-11-06 there were ~40 ConnectTimeout /
       ConnectError warnings in three days and one fatal `updater.stop()` that
       rebuilt the adapter. The gateway stays up through all of it, so the unit is
       "active" while the only channel that can reach the owner is not.
    """
    rc, out = _sh("journalctl", "--user", "-u", "hermes-gateway", "--since", "-1h",
                  "--no-pager", "-o", "cat", timeout=60)
    if rc != 0 or not out:
        return
    latched = [ln for ln in out.splitlines() if "consecutive stale attempts" in ln]
    if latched:
        problems.append(
            f"  • the model stream gave up {len(latched)}× in the last hour "
            f"(\"consecutive stale attempts\").\n"
            f"    Past 5 the SESSION IS LATCHED and fails every turn in 0.1 s — no\n"
            f"    retry, no wait. Only exits: `hermes sessions delete <id>` or a\n"
            f"    gateway restart.\n"
            f"    `journalctl --user -u hermes-gateway --since -2h | grep -i unresponsive`"
        )
    tg = [ln for ln in out.splitlines()
          if "telegram" in ln.lower() and ("ConnectTimeout" in ln or "ConnectError" in ln)]
    if len(tg) >= 20:
        problems.append(
            f"  • Telegram connectivity is degraded: {len(tg)} connect failures in the "
            f"last hour.\n"
            f"    The unit stays `active` through this, so it is invisible from "
            f"`systemctl`.\n"
            f"    `journalctl --user -u hermes-gateway --since -1h | grep -i telegram`"
        )


def check_restart_loops(problems: list[str]) -> None:
    """Units that systemd keeps restarting.

    Every long-lived unit here is `Restart=always` with `StartLimitBurst=5`, so a
    crash loop runs five times, hits the start limit, and then sits in `failed`
    — reported by check_failed_units, but only AFTER it gave up. `NRestarts > 0` on
    a unit that should never restart is the earlier signal, and inside the start
    limit it is completely silent.
    """
    for unit in ("hermes-gateway", "llamacpp-daemon", "hermes-dashboard",
                 "egress-proxy", "file-drop"):
        rc, out = _sh("systemctl", "--user", "show", "-p", "NRestarts", "--value", unit,
                      timeout=15)
        try:
            n = int(out.strip() or 0)
        except ValueError:
            continue
        if n >= 2:
            problems.append(
                f"  • `{unit}` has auto-restarted {n}× since its last start.\n"
                f"    `journalctl --user -u {unit} -n 60 --no-pager`"
            )


DAILY_STAMP = os.path.expanduser("~/.hermes/.fleet-daily")


def daily_maintenance(problems: list[str]) -> None:
    """Board hygiene that nothing runs today, at most once a day.

    `hermes kanban gc` prunes task_events and worker logs older than 30 days and
    had never been run — retention is only a promise if something calls it. The
    integrity check is the upstream `repair` verb, which quarantines the DB before
    rebuilding damaged indexes and fails closed on any other corruption class.
    """
    try:
        if time.time() - os.path.getmtime(DAILY_STAMP) < 24 * 3600:
            return
    except OSError:
        pass
    _sh(HERMES, "kanban", "gc", timeout=180)
    rc, out = _sh(HERMES, "kanban", "repair", timeout=180)
    if rc != 0:
        problems.append(
            f"  • `hermes kanban repair` reports the board DB is not clean:\n"
            f"    {' '.join(out.split())[:300]}\n"
            f"    `hermes kanban repair --json`"
        )
    try:
        open(DAILY_STAMP, "w").close()
    except OSError:
        pass


def check_ddns(problems: list[str]) -> None:
    """Is the public A record still pointing at us?

    A stale record is invisible until someone cannot connect, and the timer can
    fail silently on a bad token or a Cloudflare API change. --dry-run prints
    what it *would* do without writing, so any "would update/create" is drift.
    """
    script = os.path.expanduser("~/.local/bin/cloudflare-ddns.py")
    if not os.path.exists(script):
        return
    rc, out = _sh("/usr/bin/python3", script, "--dry-run", timeout=60)
    low = out.lower()
    if "would update" in low or "would create" in low:
        problems.append(
            "  • DDNS drift: the Cloudflare record does not match this machine's\n"
            f"    public IP ({out.strip().splitlines()[-1] if out.strip() else 'no output'})\n"
            "    `cloudflare-ddns` to fix, or `cloudflare-ddns --dry-run` to inspect"
        )
    elif rc != 0:
        problems.append(
            f"  • DDNS check failed (exit {rc}): {out.strip()[:160]}\n    `cloudflare-ddns --dry-run`"
        )


def check_model(problems: list[str]) -> None:
    try:
        with urllib.request.urlopen(MODEL_URL, timeout=15) as r:
            data = json.loads(r.read())
        ids = [m.get("id") for m in data.get("data", [])]
        if EXPECTED_MODEL not in ids:
            problems.append(
                f"  • model server is up but `{EXPECTED_MODEL}` is not offered\n"
                f"    offered: {', '.join(filter(None, ids)) or '(none)'}"
            )
    except Exception as exc:
        problems.append(
            f"  • model server unreachable at {MODEL_URL} ({type(exc).__name__})\n"
            f"    every agent turn will fail until it is back"
        )


def check_disk(problems: list[str]) -> None:
    try:
        free_gb = shutil.disk_usage(os.path.expanduser("~")).free / 1024**3
    except Exception:
        return
    if free_gb < DISK_MIN_FREE_GB:
        problems.append(
            f"  • disk low: {free_gb:.0f} GB free (threshold {DISK_MIN_FREE_GB} GB)"
        )


def _last_activity_map(task_ids: list[str]) -> dict[str, float]:
    """Newest task_events timestamp per task.

    `kanban list` only exposes created_at / started_at / completed_at, and
    started_at is written once and never updated. So a card that was blocked and
    later unblocked reports an age from its FIRST run forever — this watchdog
    reported "10h47m" for a card that had been unblocked a minute earlier.
    Alerts that cry wolf get ignored, so the age basis is the newest event.

    Best-effort: any failure falls back to whatever the CLI gave us.
    """
    import sqlite3

    out: dict[str, float] = {}
    db = os.path.expanduser("~/.hermes/kanban.db")
    if not os.path.exists(db) or not task_ids:
        return out
    try:
        conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=5)
        marks = ",".join("?" * len(task_ids))
        rows = conn.execute(
            f"SELECT task_id, MAX(created_at) FROM task_events "
            f"WHERE task_id IN ({marks}) GROUP BY task_id",
            task_ids,
        ).fetchall()
        for tid, ts in rows:
            if ts:
                out[str(tid)] = float(ts)
        conn.close()
    except Exception:
        pass
    return out


def _block_reason(task_id: str) -> str:
    """Why a card is blocked, fetched so the alert can carry it.

    `kanban list` has no reason field, so a stale card was reported as bare
    "blocked 22h" and the operator had to go dig for the why. `kanban show
    --json` has it (`latest_summary`, else the last comment). Called ONLY for
    cards that are already being reported, so a healthy fleet pays nothing.
    """
    d = _json(HERMES, "kanban", "show", task_id, "--json")
    if not isinstance(d, dict):
        return ""
    text = d.get("latest_summary") or ""
    if not text:
        comments = d.get("comments") or []
        if comments:
            text = comments[-1].get("body") or ""
    return " ".join(str(text).split())[:240]


def _repair_skills(task_id: str, bad: list[str]) -> bool:
    """Drop the unresolvable skills from a card so its next spawn can start.

    Why repair instead of report: a card whose `skills` cannot be resolved dies at
    EVERY spawn before the worker's first turn (measured: t_35165ee8, two runs,
    60s each, then the breaker parked it for a human who had no CLI verb to fix
    it — `kanban edit` only gained `--skill`/`--clear-skills` alongside this).
    Reporting it every 15 min asks the same unactionable question forever.

    Narrow on purpose: it clears the whole forced-skill list rather than guessing
    which names were meant, and it records what it removed on the card, so the
    next reader knows why the card lost its skills. Returns False if the write
    failed, in which case the caller still reports the problem.
    """
    if _sh(HERMES, "kanban", "edit", task_id, "--clear-skills")[0] == 0:
        _sh(HERMES, "kanban", "comment", task_id,
            f"fleet-check: cleared unresolvable forced skill(s) {bad}; the worker "
            f"cannot start with them. Add the real leaf name with "
            f"`hermes kanban edit {task_id} --skill <name>` if the card needs one.",
            timeout=60)
        return True
    return False


def check_board(problems: list[str]) -> None:
    assignees = _json(HERMES, "kanban", "assignees", "--json")
    if isinstance(assignees, list):
        for a in assignees:
            if a.get("on_disk"):
                continue
            held = {k: v for k, v in (a.get("counts") or {}).items() if k != "done"}
            if not held:
                continue
            problems.append(
                f"  • `{a.get('name')}` is not a profile but holds cards "
                f"({', '.join(f'{k}={v}' for k, v in sorted(held.items()))}).\n"
                f"    These never run: `hermes kanban reassign <id> <valid-profile>`"
            )

    tasks = _json(HERMES, "kanban", "list", "--json")
    if not isinstance(tasks, list):
        return
    valid_skills = _valid_skill_names()
    activity = _last_activity_map([t.get("id") for t in tasks if t.get("id")])
    for t in tasks:
        status = t.get("status") or ""
        tid = t.get("id")

        skills = t.get("skills") or []
        if isinstance(skills, str):
            try:
                skills = json.loads(skills)
            except Exception:
                skills = [skills]
        if valid_skills and isinstance(skills, list):
            bad = [s for s in skills if s and s not in valid_skills]
            if bad:
                # Only a card that can still be dispatched is worth repairing; a
                # done/archived card's skills are history, not a startup failure.
                if status not in ("done", "archived") and _repair_skills(tid, bad):
                    problems.append(
                        f"  • `{tid}` named skill(s) {bad} which do not exist.\n"
                        f"    FIXED: cleared them, so the next spawn can start. The card "
                        f"still needs a human decision — `hermes kanban show {tid}`."
                    )
                else:
                    cat_dir = os.path.expanduser("~/.hermes/skills")
                    cats = sorted(d for d in (os.listdir(cat_dir) if os.path.isdir(cat_dir) else [])
                                  if d in bad)
                    hint = (" (that is a skill CATEGORY, not a skill — names live one "
                            "level deeper, e.g. `sdlc-review`)") if cats else ""
                    problems.append(
                        f"  • `{tid}` names skill(s) {bad} which do not exist{hint}.\n"
                        f"    The worker dies at startup on every retry.\n"
                        f"    `hermes kanban edit {tid} --clear-skills`"
                    )

        # A scratch workspace is deleted when the run ends, so a REVIEW lane can
        # never see what an implementer produced — it reports an empty workspace and
        # the card ping-pongs. But that only matters for cards whose output is FILES.
        # A planning/review card's output is a verdict in the run summary, so scratch
        # is correct for it. Flagging those was a false positive in this very check:
        # t_66c37ec1 was an `architect` planning card and got reported every 15 min.
        TEXT_OUTPUT_ROLES = {"architect", "research"}
        if (status in ("review", "running")
                and t.get("workspace_kind") == "scratch"
                and (t.get("assignee") or "") not in TEXT_OUTPUT_ROLES):
            problems.append(
                f"  • `{tid}` [{status}] runs on an ephemeral `scratch` workspace.\n"
                f"    Files are deleted when the run ends, so review can never see"
                f" them and the card loops. Needs `dir:/abs/path` or `worktree`."
            )

        if status not in ("ready", "review", "blocked"):
            continue
        limit = {"ready": READY_STALE_S, "review": REVIEW_STALE_S,
                 "blocked": BLOCKED_STALE_S}[status]
        # Capability blocks are a request for a human, not a stall — surface sooner.
        if status == "blocked" and (t.get("block_kind") or "") == "capability":
            limit = CAPABILITY_STALE_S
        # Newest event beats started_at, which is written once and never updated.
        basis = activity.get(str(tid)) or t.get("started_at") or t.get("created_at")
        age = _age(basis)
        if age >= limit:
            reason = _block_reason(tid) if status == "blocked" else ""
            problems.append(
                f"  • `{tid}` [{status}] {_human(age)} — "
                f"{t.get('assignee') or 'unassigned'}: {(t.get('title') or '')[:70]}"
                + (f"\n    ↳ {reason}" if reason else "")
                + ("\n    capability block — waiting on a human to install something."
                   " `capability-check <cmd>` names the package."
                   if (t.get("block_kind") or "") == "capability" else "")
            )


def main() -> int:
    problems: list[str] = []
    for fn in (check_services, check_failed_units, check_restart_loops, check_channel,
               check_ddns, check_model, check_disk, check_serve, check_cron, check_board,
               daily_maintenance):
        try:
            fn(problems)
        except Exception as exc:  # one broken check must not hide the others
            problems.append(f"  • {fn.__name__} itself failed: {exc}")

    if not problems:
        return 0

    print("⚠️ Fleet needs attention")
    print()
    for p in problems:
        print(p)
    print()
    print("  `/kanban list` · `hermes kanban log <id>`")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"⚠️ fleet-check itself failed: {exc}", file=sys.stderr)
        sys.exit(0)
