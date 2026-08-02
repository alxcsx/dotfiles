# --- Rust (.cargo, .rustup) ---
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"

# --- .NET (.dotnet) ---
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export DOTNET_CLI_HOME="$XDG_DATA_HOME/dotnet"

# --- Node (.npm) ---
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_PREFIX="$HOME/.local"

# --- Elixir / Erlang (.hex) ---
export HEX_HOME="$XDG_DATA_HOME/hex"
export MIX_HOME="$XDG_DATA_HOME/mix"
export ERL_AFLAGS="-kernel shell_history enabled -kernel shell_history_file_bytes 1024000"

# --- GitHub Copilot ---
# Warning: COPILOT_HOME mixes config and state data. 
export COPILOT_HOME="$XDG_DATA_HOME/copilot"

# --- NVIDIA / CUDA ---
export __GL_SHADER_DISK_CACHE_PATH="$XDG_CACHE_HOME/nv"
export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"


# --- Other Tools ---
export UV_PYTHON_PREFERENCE="system"
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
