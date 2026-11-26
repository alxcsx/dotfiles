#!/usr/bin/env python3
"""pre_tool_call guard — blocks outbound web tool calls that carry structured private data.

Why a hook and not a classifier: measured on this machine, the Laya decision model
scored 5/7 on the same query strings and MISSED a raw credit-card number at
p=0.08. Deterministic patterns scored 7/7. For structured identifiers, a regex
with a checksum beats a 421M-parameter classifier — and it cannot be talked out
of its answer by prompt injection.

This is a *belt*, not a guarantee. It only sees tool arguments, so it cannot stop
private content an agent paraphrases into a query. The structural control is that
private profiles hold no remote credentials; see ~/PLAN.md.

Contract (agent/shell_hooks.py):
  stdin  {"hook_event_name","tool_name","tool_input","session_id","cwd","extra"}
  stdout {"action":"block","message":"..."}  or  exit 2
  Fails OPEN on any internal error — a broken guard must not stop the agent.
"""

from __future__ import annotations

import json
import re
import sys

# --- validators -----------------------------------------------------------------
# Checksums are the whole trick: they make these patterns precise enough that a
# legitimate search ("find that 16-digit part number") is not blocked.


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


# --- detectors ------------------------------------------------------------------
# NOTE: CNPJ is deliberately absent. It is public registry data in Brazil, and
# blocking it would break legitimate company lookups on the research profile.

CARD_RE = re.compile(r"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)")
CPF_RE = re.compile(r"(?<!\d)\d{3}\.?\d{3}\.?\d{3}-?\d{2}(?!\d)")
KEY_RE = re.compile(r"\b(?:sk|oc_sk|sk-or|ghp|gho|github_pat|xox[baprs])[-_][A-Za-z0-9_-]{16,}\b")
PEM_RE = re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")


def scan(text: str) -> str | None:
    """Return the name of the first sensitive category found, else None."""
    if PEM_RE.search(text):
        return "a private key block"
    if KEY_RE.search(text):
        return "an API key"
    if cpf_ok(text) and CPF_RE.search(text):
        return "a CPF"
    for m in CARD_RE.finditer(text):
        if luhn_ok(m.group()):
            return "a payment card number"
    return None


def walk(node, out: list[str]) -> None:
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, dict):
        for v in node.values():
            walk(v, out)
    elif isinstance(node, (list, tuple)):
        for v in node:
            walk(v, out)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # fail open: unreadable payload is not a reason to block

    tool = str(payload.get("tool_name") or "")

    # Diagnostic trail. Logs EVERY invocation, not just web tools: the first
    # failure of this guard was that it never ran at all, and a filtered log
    # could not tell "not invoked" apart from "invoked under another name".
    # ~/.hermes/logs/egress-guard.jsonl
    try:
        import os
        log = os.path.expanduser("~/.hermes/logs/egress-guard.jsonl")
        os.makedirs(os.path.dirname(log), exist_ok=True)
        with open(log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"event": payload.get("hook_event_name"), "tool": tool,
                                 "input": payload.get("tool_input")})[:1000] + "\n")
    except Exception:
        pass

    # Only outbound web tools. The terminal tool is not covered — an agent can
    # always curl; that is what the Docker/egress layer is for, not this hook.
    # Prefix match so a newly added web_* tool is covered by default rather than
    # silently exempt.
    if not tool.startswith("web_"):
        return 0

    args = payload.get("tool_input")
    if args is None:
        args = payload.get("args")
    parts: list[str] = []
    walk(args, parts)

    for text in parts:
        hit = scan(text)
        if hit:
            print(json.dumps({
                "action": "block",
                "message": (
                    f"Blocked: this outgoing web request contains {hit}. "
                    "Do not put personal or financial identifiers in a search query. "
                    "Rephrase to the general question you actually want answered "
                    "(e.g. 'refund policy for duplicate card charge' rather than the "
                    "number), or answer locally without leaving the machine."
                ),
            }))
            return 0
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)  # never break the agent loop
