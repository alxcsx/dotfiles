# Minecraft Server Submodule

Optional helpers and systemd user units for managing a containerized Minecraft server's join gate.

## Contents

- `mc-gate` — Enable or disable the shared weekly join password via RCON
- `mc-password` — Print the current shared join password
- `mc-rotate-password.sh` / `.service` / `.timer` — Weekly password rotation and Telegram announcement (uses `MC_SERVER_HOST`, defaulting to `mc.<your-domain>`)
- `mc-sync-verified` / `.service` / `.timer` — Grant weekly-password bypass to players registered in AuthMe
- `mc-verified` — List AuthMe-verified players and their bypass status

## Usage

Links executables into `~/.local/bin/` and user units into `~/.config/systemd/user/` when selected during `./dot.sh install arch_server`. Enable timers explicitly as needed:

```bash
systemctl --user enable --now mc-rotate-password.timer mc-sync-verified.timer
```
