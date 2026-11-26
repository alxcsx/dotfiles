#!/usr/bin/env python3
"""cloudflare-ddns — keep a Cloudflare A record pointed at this machine's public IPv4.

Why this runs here and not on the router: the F@st 5657 speaks the DynDNS
protocol against a fixed provider list, and Cloudflare does not speak DynDNS —
it only accepts authenticated API calls. So the updater lives on the box.

Minecraft note: the record MUST be DNS-only (grey cloud). Cloudflare's proxy
handles HTTP/HTTPS only, so a proxied record silently breaks game clients that
connect on raw TCP 25565. This script refuses to mark the record proxied.

Config: ~/.config/cloudflare-ddns/env (sourced, keep it 600, never commit it)
    CF_API_TOKEN=...        # Zone:DNS:Edit, scoped to the one zone
    CF_ZONE=example.com     # the zone name
    CF_RECORD=mc.example.com# the record to keep updated
    CF_TTL=300              # optional, default 300

Usage:
    cloudflare-ddns             # update if needed (this is what the timer runs)
    cloudflare-ddns --dry-run   # show what it would do, change nothing
    cloudflare-ddns --selftest  # no network, no config: proves the logic

Exit codes: 0 = up to date or updated; 1 = error (config, network, API).
"""
from __future__ import annotations

import json
import os
import re
import socket
import sys
import urllib.error
import urllib.request

# IPv6 toward Cloudflare's API times out on this network (measured 2026-10-18: an
# 8 s connect timeout to api.cloudflare.com, while IPv4 connects in 0.04 s).
# urllib walks getaddrinfo results in order, and here the AAAA records come
# first, so every API call burned its full timeout before falling back. We only
# ever publish an A record, so prefer IPv4 outright and keep the rest as a
# last resort.
_orig_getaddrinfo = socket.getaddrinfo


def _ipv4_first(*args, **kwargs):
    results = _orig_getaddrinfo(*args, **kwargs)
    v4 = [r for r in results if r[0] == socket.AF_INET]
    return v4 or results


socket.getaddrinfo = _ipv4_first

API = "https://api.cloudflare.com/client/v4"
ENV_PATH = os.path.expanduser("~/.config/cloudflare-ddns/env")

# Several sources, because a single one having a bad day should not stall DDNS.
IP_SOURCES = [
    "https://api.ipify.org",
    "https://ipv4.icanhazip.com",
    "https://1.1.1.1/cdn-cgi/trace",
]

IPV4 = re.compile(r"^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$")


def is_routable_ipv4(ip: str) -> bool:
    """False for private, loopback, link-local, and CGNAT (100.64/10) space.

    A CGNAT address here means the ISP is NATing us: the record would point at an
    address shared with other customers, and inbound would not reach this machine
    no matter how the router is configured. Better to fail loudly than to publish
    an address that cannot work.
    """
    m = IPV4.match(ip)
    if not m:
        return False
    a, b, c, d = (int(g) for g in m.groups())
    if any(part > 255 for part in (a, b, c, d)):
        return False
    if a == 127 or a == 0 or a >= 224:
        return False
    if a == 10 or (a == 172 and 16 <= b <= 31) or (a == 192 and b == 168):
        return False
    if a == 100 and 64 <= b <= 127:  # RFC 6598 carrier-grade NAT
        return False
    if a == 169 and b == 254:
        return False
    return True


def load_env() -> dict:
    if not os.path.exists(ENV_PATH):
        sys.exit(f"config missing: {ENV_PATH}\n"
                 f"create it with CF_API_TOKEN, CF_ZONE, CF_RECORD (chmod 600)")
    cfg: dict[str, str] = {}
    with open(ENV_PATH, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip().strip('"').strip("'")
    for key in ("CF_API_TOKEN", "CF_ZONE", "CF_RECORD"):
        if not cfg.get(key):
            sys.exit(f"{key} not set in {ENV_PATH}")
    cfg.setdefault("CF_TTL", "300")
    return cfg


def public_ipv4() -> str:
    for url in IP_SOURCES:
        try:
            with urllib.request.urlopen(url, timeout=10) as r:
                body = r.read().decode("utf-8", "replace").strip()
        except Exception:
            continue
        if url.endswith("trace"):  # key=value lines
            for line in body.splitlines():
                if line.startswith("ip="):
                    body = line[3:]
                    break
        # Some sources append a newline or brackets.
        cand = body.split()[0] if body else ""
        if is_routable_ipv4(cand):
            return cand
    sys.exit("could not determine a routable public IPv4 from any source "
             "(if every source returned a 100.64.x.x address, you are behind "
             "ISP CGNAT and inbound port forwarding cannot work)")


def api(method: str, path: str, token: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            out = json.loads(r.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:300]
        sys.exit(f"cloudflare API {e.code} on {method} {path}: {body}")
    if not out.get("success"):
        sys.exit(f"cloudflare API error on {method} {path}: {out.get('errors')}")
    return out


def selftest() -> None:
    ok = ["179.34.112.226", "8.8.8.8", "1.1.1.1", "200.160.0.1"]
    bad = ["100.64.0.1", "10.0.0.5", "192.168.1.66", "172.16.4.1",
           "127.0.0.1", "169.254.1.1", "not-an-ip", "999.1.1.1", ""]
    for ip in ok:
        assert is_routable_ipv4(ip), f"{ip} should be accepted"
    for ip in bad:
        assert not is_routable_ipv4(ip), f"{ip} should be rejected"
    print(f"selftest OK: {len(ok)} accepted, {len(bad)} rejected")


def main() -> int:
    if "--selftest" in sys.argv:
        selftest()
        return 0
    dry = "--dry-run" in sys.argv
    cfg = load_env()
    token, zone_name, record = cfg["CF_API_TOKEN"], cfg["CF_ZONE"], cfg["CF_RECORD"]
    ip = public_ipv4()

    zones = api("GET", f"/zones?name={zone_name}", token)["result"]
    if not zones:
        sys.exit(f"zone {zone_name} not found for this token")
    zone_id = zones[0]["id"]

    found = api("GET", f"/zones/{zone_id}/dns_records?type=A&name={record}", token)["result"]
    if found:
        rec = found[0]
        if rec["content"] == ip:
            print(f"unchanged: {record} -> {ip}")
            return 0
        if rec.get("proxied"):
            sys.exit(f"refusing: {record} is proxied (orange cloud). Cloudflare's "
                     f"proxy does not carry raw TCP 25565 — set it to DNS-only.")
        print(f"{'would update' if dry else 'updating'}: {record} {rec['content']} -> {ip}")
        if not dry:
            api("PATCH", f"/zones/{zone_id}/dns_records/{rec['id']}", token, {
                "content": ip, "ttl": int(cfg["CF_TTL"]), "proxied": False,
            })
        return 0

    print(f"{'would create' if dry else 'creating'}: {record} -> {ip} (DNS-only)")
    if not dry:
        api("POST", f"/zones/{zone_id}/dns_records", token, {
            "type": "A", "name": record, "content": ip,
            "ttl": int(cfg["CF_TTL"]), "proxied": False,
        })
    return 0


if __name__ == "__main__":
    sys.exit(main())
