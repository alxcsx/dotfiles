#!/usr/bin/env python3
"""fleet-tg-send — post a fleet alert to Telegram with a button to the board.

Why this exists instead of `hermes send`: the send tool has no way to attach an
inline keyboard, and the gateway's Telegram adapter dispatches callback_data
through a HARDCODED prefix whitelist (ea:, cl:, mp:, sc:, ...) with no plugin
hook and no fallthrough. An unknown prefix is silently dropped, so a button
cannot run a command — `hermes kanban unblock` stays a command. `tg-approve.py`
gets real buttons only because it blocks and polls getUpdates itself, which is
impossible for a fire-and-forget alert whose button may be tapped hours later.

So the button is a URL. Per-card buttons were tried and removed: a URL button
aimed at the per-card JSON API read worse than printing the reason inline, and
`hermes kanban unblock <id>` is one command — a per-card button that only
navigates was noise. The alert text carries the reason; the button carries the
one action.

Credentials come from ~/.hermes/.env — the same file `hermes send` uses.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

ENV = os.path.expanduser("~/.hermes/.env")
DASH = os.environ.get("HERMES_DASHBOARD_URL", "").rstrip("/")
API = "https://api.telegram.org/bot{token}/{method}"
LIMIT = 3500  # Telegram caps message text at 4096


def creds() -> tuple[str, str]:
    token = chat = ""
    with open(ENV) as fh:
        for line in fh:
            key, _, val = line.strip().partition("=")
            val = val.strip().strip('"').strip("'")
            if key == "TELEGRAM_BOT_TOKEN":
                token = val
            elif key == "TELEGRAM_HOME_CHANNEL":
                chat = val
    return token, chat


def keyboard() -> dict:
    return {"inline_keyboard": [[{"text": "📋 Open board", "url": f"{DASH}/kanban"}]]}


def post(token: str, method: str, payload: dict) -> None:
    req = urllib.request.Request(
        API.format(token=token, method=method),
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        json.load(r)


def send(text: str) -> None:
    token, chat = creds()
    if not token or not chat:
        raise SystemExit(
            f"fleet-tg-send: TELEGRAM_BOT_TOKEN / TELEGRAM_HOME_CHANNEL missing from {ENV}")
    payload = {"chat_id": chat, "text": text}
    if DASH:
        payload["reply_markup"] = keyboard()
    # The body uses `backticks` for ids and commands. Markdown renders those, but
    # an unparseable entity is a 400 and the alert would vanish — so formatting
    # never gets the last word; plain text is the fallback.
    for extra in ({"parse_mode": "Markdown"}, {}):
        try:
            post(token, "sendMessage", {**payload, **extra})
            return
        except urllib.error.HTTPError as e:
            if e.code != 400:
                raise
    raise SystemExit("fleet-tg-send: Telegram rejected the message")


def self_test() -> int:
    kb = keyboard()["inline_keyboard"]
    assert len(kb) == 1 and len(kb[0]) == 1, kb
    assert kb[0][0]["url"] == f"{DASH}/kanban", kb
    print("fleet-tg-send: self-test ok")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    body = sys.stdin.read().strip()
    if not body:
        return 0
    send(body[:LIMIT])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
