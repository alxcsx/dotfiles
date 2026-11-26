#!/usr/bin/python3
"""tg-approve — run ONE root command, but only after the owner taps Approve on Telegram.

Why not SUDO_ASKPASS: that ships your login password through Telegram's servers and
keeps it in chat history, and it makes every prompt a rubber stamp. Here the password
never moves — the thing approved is one exact argv, from one exact chat, once, with a
deadline. Fail-closed: no token, no approval, no execution.

Install (root):
    install -d -m 750 /etc/tg-approve
    umask 077; printf %s "$BOT_TOKEN" > /etc/tg-approve/token
               printf %s "$CHAT_ID"   > /etc/tg-approve/chat_id
    install -m 755 -o root -g root tg-approve.py /usr/local/sbin/tg-approve
    echo 'alex ALL=(root) NOPASSWD: /usr/local/sbin/tg-approve' > /etc/sudoers.d/tg-approve
    chmod 440 /etc/sudoers.d/tg-approve && visudo -c

Use:
    sudo tg-approve ufw-allow 25565/tcp
    sudo tg-approve ufw-delete 25565/tcp
    sudo tg-approve pacman-install htop
    sudo tg-approve systemd-unit restart docker.service
    sudo tg-approve run -- /usr/bin/install -m 600 /tmp/x /etc/x
    tg-approve --check <verb> ...   # print the resolved argv, no Telegram, no exec
    tg-approve --self-test          # validation table; exit 0 = all good

Exit codes: 0 ok/approved, 1 usage or setup error, 2 denied, 3 timed out, 4 busy, 5 exec failed.
"""

import fcntl
import json
import os
import random
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

CONF_DIR = "/etc/tg-approve"
LOCK_PATH = "/run/tg-approve.lock"
API = "https://api.telegram.org/bot{token}/{method}"
PORT_RE = re.compile(r"^(\d{1,5})(?:/(tcp|udp))?$")
PKG_RE = re.compile(r"^[a-z0-9][a-z0-9@._+-]*$")
UNIT_RE = re.compile(r"^[A-Za-z0-9@._:-]+\.(service|socket|timer|target|mount)$")
CTRL_RE = re.compile(r"[\x00-\x1f\x7f]")


class Bad(Exception):
    pass


def resolve(argv: list[str]) -> list[str]:
    """Map a request onto a concrete argv. Everything here is argv-array based —
    no shell ever sees these strings, so only the allowlist matters."""
    if not argv:
        raise Bad("no verb")
    verb, rest = argv[0], argv[1:]

    if verb in ("ufw-allow", "ufw-delete"):
        if len(rest) != 1:
            raise Bad(f"{verb} takes exactly one PORT[/tcp|udp]")
        m = PORT_RE.match(rest[0])
        if not m or not (1 <= int(m.group(1)) <= 65535):
            raise Bad(f"bad port spec: {rest[0]!r}")
        port, proto = m.group(1), m.group(2) or "tcp"
        action = "allow" if verb == "ufw-allow" else "delete"
        return ["/usr/bin/ufw", action, "in", "on", "tailscale0",
                "to", "any", "port", port, "proto", proto]

    if verb == "pacman-install":
        if not rest:
            raise Bad("pacman-install takes at least one package")
        for p in rest:
            if not PKG_RE.match(p):
                raise Bad(f"bad package name: {p!r}")
        return ["/usr/bin/pacman", "-S", "--noconfirm", "--needed", *rest]

    if verb == "systemd-unit":
        if len(rest) != 2 or rest[0] not in ("start", "stop", "restart", "enable", "disable"):
            raise Bad("systemd-unit takes <start|stop|restart|enable|disable> <unit>")
        if not UNIT_RE.match(rest[1]):
            raise Bad(f"bad unit name: {rest[1]!r}")
        return ["/usr/bin/systemctl", rest[0], rest[1]]

    if verb == "run":
        if rest[:1] != ["--"] or len(rest) < 2:
            raise Bad("run requires: run -- <absolute-path> [args...]")
        cmd = rest[1:]
        if not cmd[0].startswith("/"):
            raise Bad("run requires an absolute path as argv[0]")
        for a in cmd:
            if CTRL_RE.search(a):
                raise Bad("control characters are not allowed in arguments")
        return cmd

    raise Bad(f"unknown verb: {verb!r}")


def shellish(argv: list[str]) -> str:
    return " ".join("'" + a.replace("'", "'\\''") + "'" for a in argv)


def tg(token: str, method: str, payload: dict) -> dict:
    req = urllib.request.Request(
        API.format(token=token, method=method),
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=70) as r:
        return json.load(r)


def run_gated(argv: list[str], check_only: bool) -> int:
    if check_only:
        print(shellish(argv))
        return 0
    if os.geteuid() != 0:
        print("tg-approve: must run under sudo (NOPASSWD entry installed)", file=sys.stderr)
        return 1

    try:
        token = open(f"{CONF_DIR}/token").read().strip()
        chat = open(f"{CONF_DIR}/chat_id").read().strip()
    except OSError as e:
        print(f"tg-approve: cannot read {CONF_DIR}/token or chat_id: {e}", file=sys.stderr)
        return 1
    if not token or not chat:
        print(f"tg-approve: {CONF_DIR}/token or chat_id is empty", file=sys.stderr)
        return 1

    lock = open(LOCK_PATH, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("tg-approve: another approval is already pending", file=sys.stderr)
        return 4

    rid = "%08x" % random.getrandbits(32)
    ppid_name = "?"
    try:
        ppid_name = open(f"/proc/{os.getppid()}/comm").read().strip()
    except OSError:
        pass
    timeout = int(os.environ.get("TG_APPROVE_TIMEOUT", "300"))

    text = (f"⚠️ root approval requested\n\n"
            f"$ sudo {shellish(argv)}\n\n"
            f"id {rid} · from {ppid_name} (pid {os.getppid()}) · cwd {os.getcwd()}\n"
            f"expires in {timeout // 60} min")
    kb = {"inline_keyboard": [[
        {"text": "✅ Approve", "callback_data": f"ap:{rid}"},
        {"text": "⛔ Deny", "callback_data": f"no:{rid}"}]]}
    try:
        sent = tg(token, "sendMessage", {"chat_id": chat, "text": text, "reply_markup": kb})
        msg_id = sent["result"]["message_id"]
    except Exception as e:
        print(f"tg-approve: cannot reach Telegram: {e}", file=sys.stderr)
        return 1

    deadline = time.monotonic() + timeout
    offset = 0
    decision = None
    while time.monotonic() < deadline:
        try:
            updates = tg(token, "getUpdates", {"timeout": 25, "offset": offset,
                                               "allowed_updates": ["callback_query"]})
        except Exception:
            time.sleep(3)
            continue
        for u in updates.get("result", []):
            offset = u["update_id"] + 1
            cb = u.get("callback_query")
            if not cb or cb.get("message", {}).get("message_id") != msg_id:
                continue
            data = cb.get("data", "")
            if data == f"ap:{rid}":
                decision = "approve"
            elif data == f"no:{rid}":
                decision = "deny"
            if decision:
                try:
                    tg(token, "answerCallbackQuery",
                       {"callback_query_id": cb["id"], "text": decision})
                except Exception:
                    pass
                break
        if decision:
            break

    if not decision:
        try:
            tg(token, "editMessageText",
               {"chat_id": chat, "message_id": msg_id, "text": text + "\n\n⌛ expired — nothing was run"})
        except Exception:
            pass
        return 3

    if decision == "deny":
        try:
            tg(token, "editMessageText",
               {"chat_id": chat, "message_id": msg_id, "text": text + "\n\n⛔ denied — nothing was run"})
        except Exception:
            pass
        return 2

    try:
        tg(token, "editMessageText",
           {"chat_id": chat, "message_id": msg_id, "text": text + "\n\n▶️ approved — running"})
    except Exception:
        pass

    try:
        p = subprocess.run(argv, capture_output=True, text=True,
                           timeout=int(os.environ.get("TG_APPROVE_EXEC_TIMEOUT", "600")))
    except Exception as e:
        tg(token, "sendMessage", {"chat_id": chat, "text": f"id {rid} · failed to start: {e}"})
        return 5

    clip = lambda s: (s or "")[-2500:]
    body = (f"id {rid} · exit {p.returncode}\n\n$ {shellish(argv)}\n"
            + (f"\n{clip(p.stdout)}" if p.stdout else "")
            + (f"\n[stderr]\n{clip(p.stderr)}" if p.stderr else ""))
    try:
        tg(token, "sendMessage", {"chat_id": chat, "text": body})
    except Exception:
        pass
    sys.stdout.write(p.stdout or "")
    sys.stderr.write(p.stderr or "")
    return 0 if p.returncode == 0 else 5


def self_test() -> int:
    ok = [("ufw-allow 25565/tcp", ["/usr/bin/ufw", "allow", "in", "on", "tailscale0",
                                   "to", "any", "port", "25565", "proto", "tcp"]),
          ("ufw-delete 53/udp", ["/usr/bin/ufw", "delete", "in", "on", "tailscale0",
                                 "to", "any", "port", "53", "proto", "udp"]),
          ("pacman-install htop", ["/usr/bin/pacman", "-S", "--noconfirm", "--needed", "htop"]),
          ("systemd-unit restart docker.service", ["/usr/bin/systemctl", "restart", "docker.service"]),
          ("run -- /bin/echo hi", ["/bin/echo", "hi"])]
    bad = ["ufw-allow 99999", "ufw-allow 25565/icmp", "ufw-allow 25565/tcp extra",
           "ufw-allow '25565/tcp; rm -rf /'", "pacman-install ../evil", "pacman-install -Sfoo",
           "systemd-unit rm docker", "systemd-unit restart docker", "run -- echo hi",
           ["run", "--", "/bin/echo", "a\nb"], ["run", "--", "/bin/echo", "a\x7fb"],
           "", "nonsense verb"]
    for req, want in ok:
        got = resolve(req.split())
        assert got == want, f"{req!r}: got {got}"
    for req in bad:
        args = req.split() if isinstance(req, str) else req
        try:
            resolve(args)
        except Bad:
            continue
        raise AssertionError(f"{req!r} was accepted but should be rejected")
    print(f"self-test: {len(ok)} accepted, {len(bad)} rejected — OK")
    return 0


def main() -> int:
    argv = sys.argv[1:]
    if argv[:1] == ["--self-test"]:
        return self_test()
    check_only = argv[:1] == ["--check"]
    if check_only:
        argv = argv[1:]
    try:
        cmd = resolve(argv)
    except Bad as e:
        print(f"tg-approve: {e}\nusage: tg-approve <verb> ... (see --self-test)", file=sys.stderr)
        return 1
    return run_gated(cmd, check_only)


if __name__ == "__main__":
    sys.exit(main())
