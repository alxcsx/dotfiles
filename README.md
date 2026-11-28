# Dotfiles

Modular dotfiles manager for Arch Linux and macOS, orchestrated via `dot.sh`.

## Modules

- `dev/` - Core development toolchain (`mise`, `uv`, XDG env)
- `zsh/` - Zsh configuration and aliases
- `kitty/` - Kitty terminal configuration
- `emacs/` - Emacs configuration and launchers
- `arch/` - Arch Linux desktop environment (Hyprland, Noctalia, host overrides)
- `arch_server/` - Arch Linux server helpers (including `sudo-queue`)
- `ai/` - Cross-agent orchestration (`ask`, `orch`, `agent-gate`, `agent-quota`, `omp`, `codex`, `claude`, `copilot`)
- `local-ai/` - Local `llama.cpp` router (`llamacpp-daemon.service`), hardware/host presets, and on-demand GGUF puller (`local-ai-pull`)
- `ai-assistant/` - Optional Linux server tooling for Hermes fleet and Laya ([setup](ai-assistant/README.md))
- `macos/` - macOS-specific setup

See [MACHINES.md](MACHINES.md) for per-machine hardware profiles, installed modules, and quick health checks.

## Usage

Install one or more modules:

```bash
./dot.sh install dev zsh ai local-ai
```

Preview without making changes:

```bash
./dot.sh --dry-run install local-ai
```

Check installed module status:

```bash
./dot.sh status
```

Download local GGUF models on demand (for the current host manifest or a hardware profile):

```bash
local-ai-pull --host
local-ai-pull --profile gpu-16gb
```
