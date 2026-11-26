#!/usr/bin/env python3
"""sudo-approve — the ONLY thing on this box that runs a queued command as root.

Why it exists: an agent with sudo is an LLM with root, and this box publishes a Minecraft
port and holds a Telegram token. So the agent never executes privileged work — it parks a
script in ~/.local/state/sudo-queue (see `sudo-queue add`) and this service asks the human. The
human's own Telegram account is the approval factor: it cannot be forged by the agent,
which only has the *Hermes* bot token, not this bot's and not the user's account.

Design rules, do not relax them:
  * only messages from OPERATOR_ID are read; anything else is dropped silently
  * no arbitrary commands — `/run <id>` executes a file that was already in the queue
  * every action appends to $DIR/done/audit.log and the journal
  * stdlib only: no dependency on the fleet being healthy to be able to fix the fleet

Config (/etc/sudo-approve/env, root 0600):
  SUDO_APPROVE_TOKEN=123:ABC...        bot token from @BotFather (a NEW bot, not Hermes)
  SUDO_APPROVE_OPERATOR=123456789      your numeric Telegram user id (@userinfobot)
  SUDO_APPROVE_DIR=/home/alex/.local/state/sudo-queue
"""
import json, os, re, shutil, subprocess, sys, time, urllib.request, urllib.error

TOKEN = os.environ.get("SUDO_APPROVE_TOKEN", "")
OPERATOR = os.environ.get("SUDO_APPROVE_OPERATOR", "")
DIR = os.path.expanduser(os.environ.get("SUDO_APPROVE_DIR", "/home/alex/.local/state/sudo-queue"))
DONE = os.path.join(DIR, "done")
API = "https://api.telegram.org/bot%s/" % TOKEN
ID_RE = re.compile(r"\d{6}(-\d+)?")
RUN_TIMEOUT = 300

HELP = (
    "Privileged queue. The agent can add, only you can run.\n"
    "/pending — what is waiting\n"
    "/show <id> — the exact script\n"
    "/run <id> — run it as root\n"
    "/deny <id> — drop it\n"
    "(default: you are the only account this bot answers)"
)


def api(method, **params):
    if not TOKEN:
        raise RuntimeError("SUDO_APPROVE_TOKEN is not set")
    data = json.dumps(params).encode()
    req = urllib.request.Request(API + method, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)


def say(chat_id, text, mono=False):
    text = text if len(text) < 3800 else text[:3800] + "\n…truncated"
    try:
        api("sendMessage", chat_id=chat_id, text=("```\n%s\n```" % text) if mono else text,
            parse_mode="Markdown", disable_web_page_preview=True)
    except urllib.error.HTTPError:
        api("sendMessage", chat_id=chat_id, text=text)  # unparseable markdown


def audit(line):
    os.makedirs(DONE, exist_ok=True)
    with open(os.path.join(DONE, "audit.log"), "a") as fh:
        fh.write("%s %s\n" % (time.strftime("%Y-%m-%dT%H:%M:%S"), line))


def pending():
    try:
        return sorted(f[:-3] for f in os.listdir(DIR)
                      if f.endswith(".sh") and ID_RE.fullmatch(f[:-3]))
    except FileNotFoundError:
        return []


def path_of(qid):
    """Resolve a queue id to its script, or None. The regex is the path-traversal guard."""
    if not ID_RE.fullmatch(qid or ""):
        return None
    p = os.path.join(DIR, qid + ".sh")
    return p if os.path.isfile(p) and os.path.realpath(p).startswith(os.path.realpath(DIR)) else None


def describe(qid):
    try:
        with open(os.path.join(DIR, qid + ".meta")) as fh:
            meta = fh.read().strip()
    except OSError:
        meta = "(no metadata)"
    try:
        with open(path_of(qid)) as fh:
            body = fh.read()
    except (OSError, TypeError):
        return "no such queue item: %s" % qid
    return "%s\n\n%s" % (meta, body)


def finish(qid, verdict):
    os.makedirs(DONE, exist_ok=True)
    for ext in (".sh", ".meta"):
        src = os.path.join(DIR, qid + ext)
        if os.path.exists(src):
            shutil.move(src, os.path.join(DONE, qid + ext + "." + verdict))


def handle(chat_id, text):
    parts = text.strip().split()
    if not parts:
        return
    cmd = parts[0].lower().lstrip("/")
    arg = parts[1] if len(parts) > 1 else ""

    if cmd in ("start", "help"):
        return say(chat_id, HELP)
    if cmd in ("pending", "p"):
        items = pending()
        if not items:
            return say(chat_id, "nothing waiting")
        return say(chat_id, "waiting:\n" + "\n".join(
            "%s  %s" % (q, describe(q).splitlines()[0].replace("why: ", "")) for q in items))
    if cmd == "show":
        return say(chat_id, describe(arg), mono=True)
    if cmd == "deny":
        p = path_of(arg)
        if not p:
            return say(chat_id, "no such queue item: %s" % arg)
        audit("DENY %s" % arg)
        finish(arg, "denied")
        return say(chat_id, "denied %s" % arg)
    if cmd == "run":
        p = path_of(arg)
        if not p:
            return say(chat_id, "no such queue item: %s" % arg)
        say(chat_id, "▶️ running %s as root" % arg)
        audit("RUN %s" % arg)
        try:
            r = subprocess.run(["/usr/bin/bash", p], capture_output=True, text=True,
                               timeout=RUN_TIMEOUT, cwd="/root")
            out = (r.stdout + r.stderr).strip() or "(no output)"
            verdict, line = "ok" if r.returncode == 0 else "failed", "exit %d" % r.returncode
        except subprocess.TimeoutExpired:
            out, verdict, line = "timed out after %ds" % RUN_TIMEOUT, "timeout", "timeout"
        finish(arg, verdict)
        audit("DONE %s %s" % (arg, line))
        return say(chat_id, "%s %s — %s\n\n%s" % ("✅" if verdict == "ok" else "❌", arg, line, out),
                   mono=True)
    return say(chat_id, "unknown command. " + HELP)


def watch_loop():
    """Long-poll; newly queued items are announced by THIS service, not by the agent."""
    offset, announced, last_ping = 0, {q: True for q in pending()}, 0.0
    off_path = os.path.join(DIR, ".offset")
    try:
        offset = int(open(off_path).read().strip())
    except (OSError, ValueError):
        pass

    while True:
        # announce anything the agent added since the last look (rate-limited, count only)
        fresh = [q for q in pending() if q not in announced]
        for q in fresh:
            announced[q] = True
        if fresh and time.time() - last_ping > 10 and OPERATOR:
            last_ping = time.time()
            say(OPERATOR, "🔐 %d privileged script(s) waiting. /pending, then /show <id> and "
                          "/run <id> — nothing runs until you say so." % len(pending()))
        try:
            res = api("getUpdates", offset=offset, timeout=25, allowed_updates=["message"])
        except Exception as e:  # network, 502, token wrong: back off, never die
            print("poll failed: %s" % e, file=sys.stderr, flush=True)
            time.sleep(10)
            continue
        for upd in res.get("result", []):
            offset = upd["update_id"] + 1
            try:
                open(off_path, "w").write(str(offset))
            except OSError:
                pass
            msg = upd.get("message") or {}
            sender = str((msg.get("from") or {}).get("id", ""))
            text = msg.get("text") or ""
            if not OPERATOR:
                say(msg.get("chat", {}).get("id"), "set SUDO_APPROVE_OPERATOR to %s first" % sender)
                continue
            if sender != OPERATOR:
                audit("IGNORED from %s" % sender)
                continue
            handle(msg["chat"]["id"], text)
        time.sleep(1)


def selftest():
    """Runnable check: parsing and the traversal guard. No network, no token needed."""
    global OPERATOR
    assert ID_RE.fullmatch("193045"), "plain id"
    assert ID_RE.fullmatch("193045-2"), "id with collision suffix"
    assert not ID_RE.fullmatch("../etc/passwd"), "traversal must not parse"
    assert not ID_RE.fullmatch("193045/../../etc/shadow"), "traversal must not parse"
    os.makedirs(DIR, exist_ok=True)
    probe = os.path.join(DIR, "999999.sh")
    open(probe, "w").write("echo probe\n")
    assert path_of("999999") == probe, "existing item resolves"
    assert path_of("999999/../../../etc/passwd") is None, "traversal resolves to None"
    assert path_of("000001") is None, "missing item resolves to None"
    assert describe("999999").endswith("echo probe\n"), "describe shows the body"
    os.remove(probe)
    print("selftest ok: parser, traversal guard, resolve, describe")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
        sys.exit(0)
    if not TOKEN:
        sys.exit("SUDO_APPROVE_TOKEN is empty — put it in /etc/sudo-approve/env")
    os.umask(0o077)
    print("sudo-approve up: queue=%s operator=%s" % (DIR, OPERATOR or "UNSET"), flush=True)
    watch_loop()
