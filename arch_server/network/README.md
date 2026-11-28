# Network Submodule

Optional networking, dynamic DNS, and service-sharing helpers for Linux servers.

## Contents

- `cloudflare-ddns.py` / `.service` / `.timer` — Keep a Cloudflare DNS `A` record updated with the host's public IPv4 (reads credentials from `~/.config/cloudflare-ddns/env`)
- `wan-check` — Probe whether a public port (default `25565`) is reachable from the internet
- `share` — Serve a temporary file or directory over Tailscale/HTTP
- `exo-healthguard` — Restart unhealthy test instances automatically

## Usage

Links scripts into `~/.local/bin/` and `cloudflare-ddns.{service,timer}` into `~/.config/systemd/user/` when selected during `./dot.sh install arch_server`.
