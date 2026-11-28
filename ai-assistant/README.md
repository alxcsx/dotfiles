# Local AI assistant (Linux servers)

`./dot.sh install ai-assistant` installs the configuration and links for the
local llama.cpp router, optional Laya decision model, and Hermes fleet tools.
The `ai` module remains independent and installs OMP and its remote-agent
orchestration; laptops do not need this module. Existing Pi credentials and
configuration are retained and are not used by OMP.

The installer links services but does not enable or start them, install models,
apply fleet settings, or provision credentials. Configure the services needed on
this server before enabling them:

- Local `llama.cpp` is managed by the `local-ai` module (`./dot.sh install local-ai`).
  Enable it with `systemctl --user enable --now llamacpp-daemon.service`.
- For Laya, create `~/.local/share/laya` with Python 3.13 and install
  `laya[serve,mcp]` into that environment. Enable `laya-serve.service` if
  needed. To expose it to OMP, add `laya-mcp-server` to your OMP MCP config;
  it connects to the local Laya service.
- Install and configure Hermes separately. Review `hermes/fleet.conf` before
  running `fleet-apply.sh`; enable the desired Hermes timers explicitly.
  Backup, networking, proxy, and Minecraft services require their own local
  configuration and credentials. No secrets belong in this repository.
