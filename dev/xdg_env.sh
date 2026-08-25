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
export NODE_REPL_HISTORY="$XDG_DATA_HOME/node_repl_history"
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export BUN_INSTALL="$XDG_DATA_HOME/bun"


# --- Elixir / Erlang (.hex) ---
export HEX_HOME="$XDG_DATA_HOME/hex"
export MIX_HOME="$XDG_DATA_HOME/mix"
export ERL_AFLAGS="-kernel shell_history enabled -kernel shell_history_file_bytes 1024000"

# --- NVIDIA / CUDA ---
export __GL_SHADER_DISK_CACHE_PATH="$XDG_CACHE_HOME/nv"
export CUDA_CACHE_PATH="$XDG_CACHE_HOME/nv"

# --- AI STUF
export COPILOT_HOME="$XDG_DATA_HOME/copilot"
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi"
export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
export OLLAMA_MODELS="$XDG_DATA_HOME/ollama/models"
export HF_HOME="$XDG_DATA_HOME/huggingface"

# --- MISC LANGUAGES
export PYTHONUSERBASE="$XDG_DATA_HOME/python"
export GOPATH="$XDG_DATA_HOME/go"
# --- Other Tools ---
export UV_PYTHON_PREFERENCE="system"
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME/aws/credentials"
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME/aws/config"
