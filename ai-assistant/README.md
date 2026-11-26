# Local AI assistant (Linux servers)

`./dot.sh install ai-assistant` installs the configuration and links for the
local llama.cpp router, optional Laya decision model, and Hermes fleet tools.
The `ai` module remains independent and installs OMP and its remote-agent
orchestration; laptops do not need this module. Existing Pi credentials and
configuration are retained and are not used by OMP.

The installer links services but does not enable or start them, install models,
apply fleet settings, or provision credentials. Configure the services needed on
this server before enabling them:

- Install `llama-server`, put model files on the machine, and edit
  `~/.config/llamacpp/models-preset.ini` (seeded from the example). Then run
  `systemctl --user enable --now llamacpp-daemon.service`.
- For Laya, create `~/.local/share/laya` with Python 3.13 and install
  `laya[serve,mcp]` into that environment. Enable `laya-serve.service` if
  needed. To expose it to OMP, add `laya-mcp-server` to your OMP MCP config;
  it connects to the local Laya service.
- Install and configure Hermes separately. Review `hermes/fleet.conf` before
  running `fleet-apply.sh`; enable the desired Hermes timers explicitly.
  Backup, networking, proxy, and Minecraft services require their own local
  configuration and credentials. No secrets belong in this repository.

`ai/hermes`, `ai/llamacpp`, and `ai/laya` are compatibility symlinks to this
module so existing server links and loaded service definitions keep working
during migration. New references should use `ai-assistant`.
