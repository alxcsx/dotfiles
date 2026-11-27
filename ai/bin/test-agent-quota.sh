#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
state=$(mktemp -d)
trap 'rm -rf "$state"' EXIT

XDG_STATE_HOME="$state" "$root/ai/bin/agent-quota" set claude low 2099-01-01T00:00:00Z
output=$(XDG_STATE_HOME="$state" "$root/ai/bin/agent-quota")
grep -q '^claude .* normal .*resets in ' <<<"$output"

if XDG_STATE_HOME="$state" "$root/ai/bin/agent-quota" set claude low tomorrow 2>/dev/null; then
  exit 1
fi
