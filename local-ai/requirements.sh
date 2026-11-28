#!/usr/bin/env bash
# name:		local-ai.requirements.sh
# desc:		requirements for local-ai module (llama.cpp router + model puller)

if false; then
  source "../dot.sh"
fi

require_pkgs jq curl arch:llama.cpp macos:llama.cpp

if command -v uv >/dev/null 2>&1; then
  step "Install or update huggingface-hub (uv)" \
    uv tool install --upgrade huggingface-hub
fi
