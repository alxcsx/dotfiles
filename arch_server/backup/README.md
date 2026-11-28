# Backup Submodule

Optional backup, local snapshot, and hygiene-scan tools for Linux servers.

## Contents

- `backup.sh` / `backup.service` / `backup.timer` — Encrypted Restic backups to remote storage (`rclone`), alerting on failure
- `btrfs-snapshot.sh` / `btrfs-snapshot.service` / `btrfs-snapshot.timer` — Read-only btrfs snapshots of `@home`
- `maintenance-scan.sh` — Deterministic weekly hygiene scan (disks, services, DDNS, backups)

## Usage

Links scripts into `~/.local/bin/` and units into `~/.config/systemd/user/` when selected during `./dot.sh install arch_server`. Enable timers explicitly after configuring your Restic repository and credentials.
