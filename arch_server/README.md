# Arch Server

Base setup and optional server submodules for Linux hosts (`./dot.sh install arch_server`).

## Base setup (`install.sh`)

- Enables `tailscaled` (with `--ssh` and operator access) and `sshd`
- Installs `10-server-lid.conf` to ignore laptop lid-close suspend on headless servers
- Adds `consoleblank=60` to `/etc/kernel/cmdline` when present

## Submodules

During interactive installation, `install.sh` prompts `[y/N]` for each optional submodule below:

- [minecraft_server/](minecraft_server/README.md) — Minecraft join-password gate, weekly password rotation, and AuthMe bypass sync
- [network/](network/README.md) — Cloudflare dynamic DNS, public port probe, temporary file sharing, and service healthguard
- [backup/](backup/README.md) — Restic off-site backups, read-only btrfs `@home` snapshots, and weekly hygiene scan
- [static-sites/](static-sites/README.md) — Caddy + File Browser Next Podman Quadlets for Tailnet-only uploads and public static hosting
- [sudo-queue/](sudo-queue/README.md) — Headless operator approval queue for privileged requests
