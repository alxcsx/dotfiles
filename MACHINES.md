# Machines

Overview of machines managed by this repository (hardware, modules, and local AI profiles). No private IPs, tokens, or private endpoints.

## `janga` (Primary Desktop — Arch Linux / Hyprland)

- **Hardware:** AMD Ryzen 9 5900XT (16c/32t), 62 GiB RAM, NVIDIA GeForce RTX 4070 Ti SUPER (16 GB VRAM)
- **Installed `dot.sh` modules:** `emacs`, `kitty`, `dev`, `zsh`, `arch`, `ai`, `local-ai`
- **Host overrides:** [arch/hosts/janga/](arch/hosts/janga/)
- **Local AI (`local-ai`):** `gpu-16gb` profile / [janga.manifest](local-ai/hosts/janga.manifest)
  - `local-code`: `qwen3-14b.gguf` (~8.7 GiB, `Q4_K_M`)
  - `local-general`: `gpt-oss-20b.gguf` (~12.9 GiB, `MXFP4`)
  - `local-fast`: `qwen3-8b.gguf` (~4.9 GiB, `Q4_K_M`)
- **Quick check:**
  ```bash
  ./dot.sh status
  local-ai-pull --host janga --list
  agent-quota
  systemctl --user status llamacpp-daemon.service
  ```

## `derby` (Server — Arch Linux / Hermes)

- **Operational profile:** server running `llamacpp-daemon` and `hermes-gateway`; thermally constrained under sustained load (see [fleet.conf](ai-assistant/hermes/fleet.conf))
- **Installed `dot.sh` modules:** `dev`, `zsh`, `ai`, `local-ai`, `ai-assistant`, `arch_server`
- **Local AI (`local-ai`):** [derby.manifest](local-ai/hosts/derby.manifest)
- **Quick check:**
  ```bash
  ./dot.sh status
  local-ai-pull --host derby --list
  systemctl --user status llamacpp-daemon.service hermes-gateway.service
  ```
