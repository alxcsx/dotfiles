#!/usr/bin/env bash
# Local AI module: llama.cpp dynamic router, systemd user service, and on-demand model puller.

LOCAL_AI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/llamacpp"
LOCAL_AI_MODELS_DIR="$LOCAL_AI_CONFIG_DIR/models"
LOCAL_AI_BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
LOCAL_AI_UNITS="$HOME/.config/systemd/user"

detect_local_ai_profile() {
  local vram_mib=0
  if command -v nvidia-smi >/dev/null 2>&1; then
    vram_mib=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null |
      awk 'NR==1 {gsub(/[^0-9]/,"",$1); print $1+0}')
  fi
  if [ "${vram_mib:-0}" -ge 14000 ]; then
    echo "gpu-16gb"
  elif [ "${vram_mib:-0}" -ge 7000 ]; then
    echo "gpu-8gb"
  else
    echo "cpu"
  fi
}

seed_preset_from_profile() {
  local src="$1" dst="$2"
  sed "s|__MODELS_DIR__|$LOCAL_AI_MODELS_DIR|g" "$src" >"$dst"
}

step "Create local-ai directories" mkdir -p \
  "$LOCAL_AI_MODELS_DIR" "$LOCAL_AI_BIN_DIR" "$LOCAL_AI_UNITS"

host_name="${HOSTNAME:-$(uname -n)}"
host_name="${host_name%%.*}"
profile=$(detect_local_ai_profile)
profile=$(ask_input "Hardware profile (gpu-16gb, gpu-8gb, cpu)" "$profile")
preset_label="$profile"
profile_file="$MODULE_DIR/profiles/$profile.ini"
if [ -f "$MODULE_DIR/hosts/${host_name}.ini" ]; then
  preset_label="$host_name"
  profile_file="$MODULE_DIR/hosts/${host_name}.ini"
fi

step --skip-if '[ -f "$LOCAL_AI_CONFIG_DIR/models-preset.ini" ]' \
  "Seed llama.cpp preset ($preset_label)" \
  seed_preset_from_profile "$profile_file" "$LOCAL_AI_CONFIG_DIR/models-preset.ini"

link_file "$MODULE_DIR/llamacpp/llama-router.sh" "$LOCAL_AI_CONFIG_DIR/llama-router.sh"
link_file "$MODULE_DIR/bin/local-ai-pull" "$LOCAL_AI_BIN_DIR/local-ai-pull"

if [ "${OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}" = "linux" ]; then
  link_file "$MODULE_DIR/llamacpp/llamacpp-daemon.service" "$LOCAL_AI_UNITS/llamacpp-daemon.service"
  step "Reload systemd user units" systemctl --user daemon-reload
fi

pull_args=(--profile "$profile")
[ -f "$MODULE_DIR/hosts/${host_name}.manifest" ] && pull_args=(--host "$host_name")

if ask_yn "Download models (${pull_args[*]}) now?" n; then
  "$LOCAL_AI_BIN_DIR/local-ai-pull" "${pull_args[@]}"
else
  printf 'To download models later: local-ai-pull %s\n' "${pull_args[*]}"
fi

if [ "${OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}" = "linux" ] &&
  ask_yn "Enable and start llamacpp-daemon.service now?" n; then
  step "Enable llamacpp-daemon.service" systemctl --user enable --now llamacpp-daemon.service
fi
