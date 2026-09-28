#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Launching llama.cpp dynamic router..."
echo "Config Path:  ${BASE_DIR}/models-preset.ini"

exec llama-server \
    --models-preset "${BASE_DIR}/models-preset.ini" \
    --host 127.0.0.1 \
    --port 58000 \
    --models-max 1
