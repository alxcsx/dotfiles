#!/usr/bin/env python3
"""egress-proxy — sanitizing OpenAI-API proxy for remote models, 127.0.0.1:58020.

Why this exists: hermes' pre_tool_call hook never fires (v0.21.7 bug), and a
hook only sees tool arguments anyway. This proxy sits on the wire, so it sees
EVERYTHING sent to a remote model — including what the agent paraphrased into
the prompt — and the remote API key lives here, not in any hermes config.

What it does, in order:
  1. Holds the upstream API key (from ~/.config/egress-proxy/env). Hermes
     profiles point here with api_key "none" and never hold a credential.
  2. Deterministically redacts PII/secrets from request bodies before they
     leave: payment cards (Luhn), CPF (checksum), API keys, PEM blocks,
     emails. Validators copied from guard-private-egress.py — measured 7/7
     there; regex+checksum beats the 421M classifier (5/7, missed a card).
  3. Logs ONLY redaction counts+categories to ~/.hermes/logs/egress-proxy.jsonl.
     Never the matched text — the log must not become the leak.

What it cannot do: catch "my daughter's school is..." — unstructured personal
context has no regex. The real control stays routing: private-context tasks go
to the local model; this is the belt for public-safe tasks sent remotely.

Env (from ~/.config/egress-proxy/env):
  EGRESS_UPSTREAM  default https://api.openai.com
  EGRESS_API_KEY   required for remote use; empty = 502 with instructions
  EGRESS_PORT      default 58020

Self-check:  python3 egress-proxy.py --self-test
"""
from __future__ import annotations

import http.client
import json
import os
import re
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

# --- validators (copied from guard-private-egress.py — keep in sync) ----------

def luhn_ok(raw: str) -> bool:
    digits = [int(c) for c in raw if c.isdigit()]
    if not 13 <= len(digits) <= 19:
        return False
    total, double = 0, False
    for d in reversed(digits):
        if double:
            d *= 2
            if d > 9:
                d -= 9
        total += d
        double = not double
    return total % 10 == 0


def cpf_ok(raw: str) -> bool:
    d = [int(c) for c in raw if c.isdigit()]
    if len(d) != 11 or len(set(d)) == 1:
        return False
    for cut in (9, 10):
        want = sum(d[i] * ((cut + 1) - i) for i in range(cut)) * 10 % 11 % 10
        if want != d[cut]:
            return False
    return True


CARD_RE = re.compile(r"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)")
CPF_RE = re.compile(r"(?<!\d)\d{3}\.?\d{3}\.?\d{3}-?\d{2}(?!\d)")
KEY_RE = re.compile(r"\b(?:sk|oc_sk|sk-or|ghp|gho|github_pat|xox[baprs])[-_][A-Za-z0-9_-]{16,}\b")
PEM_RE = re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----|-----BEGIN [A-Z ]*PRIVATE KEY-----", re.S)
EMAIL_RE = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.]+\b")
# CNPJ deliberately absent: public registry data, blocking breaks company lookups.


def redact_str(s: str, counts: dict) -> str:
    def bump(cat):
        counts[cat] = counts.get(cat, 0) + 1

    def sub(pattern, repl, cat, text, guard=None):
        def _rep(m):
            if guard and not guard(m.group()):
                return m.group()
            bump(cat)
            return repl
        return pattern.sub(_rep, text)

    s = sub(PEM_RE, "[redacted-private-key]", "private_key", s)
    s = sub(KEY_RE, "[redacted-api-key]", "api_key", s)
    s = sub(CPF_RE, "[redacted-cpf]", "cpf", s, guard=cpf_ok)
    s = sub(CARD_RE, "[redacted-card]", "card", s, guard=luhn_ok)
    s = sub(EMAIL_RE, "[redacted-email]", "email", s)
    return s


def redact_node(node, counts: dict):
    if isinstance(node, str):
        return redact_str(node, counts)
    if isinstance(node, dict):
        return {k: redact_node(v, counts) for k, v in node.items()}
    if isinstance(node, list):
        return [redact_node(v, counts) for v in node]
    return node


def log_event(rec: dict) -> None:
    try:
        path = os.path.expanduser("~/.hermes/logs/egress-proxy.jsonl")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec) + "\n")
    except Exception:
        pass  # logging must never break the proxy


# --- proxy ---------------------------------------------------------------------

UPSTREAM = os.environ.get("EGRESS_UPSTREAM", "https://api.openai.com").rstrip("/")
API_KEY = os.environ.get("EGRESS_API_KEY", "")
PORT = int(os.environ.get("EGRESS_PORT", "58020"))
HOP_BY_HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
              "te", "trailers", "transfer-encoding", "upgrade",
              "authorization", "content-length", "host", "accept-encoding"}


class Handler(BaseHTTPRequestHandler):
    # HTTP/1.0 on purpose: responses are close-delimited, so streaming (SSE)
    # passes through chunk-by-chunk without Content-Length bookkeeping.
    def _proxy(self):
        if not API_KEY:
            self._json_reply(502, {"error": "egress-proxy: no EGRESS_API_KEY in "
                                   "~/.config/egress-proxy/env — add one, then "
                                   "`systemctl --user restart egress-proxy`"})
            return
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        redactions: dict = {}
        if body and "json" in (self.headers.get("Content-Type") or ""):
            try:
                redactions = {}
                payload = redact_node(json.loads(body), redactions)
                if redactions:
                    body = json.dumps(payload).encode()
                    log_event({"ts": int(time.time()), "path": self.path,
                               "redactions": redactions})
            except json.JSONDecodeError:
                pass  # non-JSON body passes through; not our job
            except Exception as e:
                log_event({"ts": int(time.time()), "path": self.path,
                           "proxy_error": f"{type(e).__name__}: {e}"})  # loud, not silent

        up = urlsplit(UPSTREAM)
        conn_cls = http.client.HTTPSConnection if up.scheme == "https" else http.client.HTTPConnection
        conn = conn_cls(up.hostname, up.port or (443 if up.scheme == "https" else 80), timeout=600)
        headers = {k: v for k, v in self.headers.items()
                   if k.lower() not in HOP_BY_HOP}
        headers["Authorization"] = f"Bearer {API_KEY}"
        headers["Connection"] = "close"
        try:
            conn.request(self.command, up.path + self.path, body=body, headers=headers)
            resp = conn.getresponse()
        except Exception as e:
            self._json_reply(502, {"error": f"egress-proxy: upstream {UPSTREAM} unreachable: {e}"})
            return
        self.send_response(resp.status)
        for k, v in resp.getheaders():
            if k.lower() not in HOP_BY_HOP:
                self.send_header(k, v)
        self.end_headers()
        while True:
            chunk = resp.read(8192)
            if not chunk:
                break
            try:
                self.wfile.write(chunk)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                break
        conn.close()

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = _proxy

    def _json_reply(self, code: int, obj: dict):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):  # quiet; redactions go to the jsonl log
        pass


def self_test() -> None:
    def r(s):
        counts: dict = {}
        return redact_node(json.loads(json.dumps(s)), counts), counts
    out, counts = r({"messages": [{"role": "user", "content":
        "my card 4539 1488 0343 6467, cpf 529.982.247-25, mail me@example.com, "
        "key sk-abcdefghijklmnop1234, part number 12345678"}]})
    text = out["messages"][0]["content"]
    assert "4539" not in text and "redacted-card" in text
    assert "529.982.247-25" not in text and "me@example.com" not in text
    assert "sk-abcdef" not in text
    assert "12345678" in text, "8-digit part number must survive (luhn guard)"
    _, c2 = r("-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----")
    assert c2.get("private_key") == 1
    _, c3 = r({"a": [{"b": "4111111111111111"}]})  # nested walk
    assert c3.get("card") == 1
    print("egress-proxy self-test OK:", counts)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
        sys.exit(0)
    print(f"egress-proxy on 127.0.0.1:{PORT} -> {UPSTREAM} (key: {'set' if API_KEY else 'MISSING'})")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
