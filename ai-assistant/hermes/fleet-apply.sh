#!/usr/bin/env bash
# fleet-apply.sh — apply fleet.conf to the main config and every profile config.
#
# Idempotent. Run it after any change to fleet.conf, after adding a profile, or
# after `hermes update`. It prints what it changed and exits non-zero if any
# write failed, so it is safe to run from a timer as a drift check.
#
#   ./fleet-apply.sh --dry-run     show what would change, write nothing
#   ./fleet-apply.sh --check       exit 1 if anything WOULD change (drift alarm)
set -uo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=fleet.conf
source "$HERE/fleet.conf"

DRY=0
CHECK=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --check)   CHECK=1 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

hermes() { command hermes "$@"; }

# ── Resolve the mode from the hardware ───────────────────────────────────────
gpu_count() {
  if ! command -v nvidia-smi >/dev/null 2>&1; then echo 0; return; fi
  local n
  n=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | grep -c .)
  echo "${n:-0}"
}

GPUS=$(gpu_count)
case "$FLEET_MODE" in
  queue)  MODE=queue ;;
  fleet)  MODE=fleet ;;
  auto|"")
    if [ "$GPUS" -le 1 ]; then MODE=queue; else MODE=fleet; fi ;;
  *) echo "invalid FLEET_MODE='$FLEET_MODE'" >&2; exit 2 ;;
esac

if [ "$MODE" = "queue" ]; then
  MAX_IN_PROGRESS="$QUEUE_MAX_IN_PROGRESS"
  LLAMA_PARALLEL="$QUEUE_LLAMA_PARALLEL"
else
  MAX_IN_PROGRESS="${FLEET_MAX_IN_PROGRESS:-$GPUS}"
  LLAMA_PARALLEL="$FLEET_LLAMA_PARALLEL"
fi

echo "fleet: mode=$MODE (gpus=$GPUS)  max_in_progress=$MAX_IN_PROGRESS  llama_parallel=$LLAMA_PARALLEL"

# ── The canonical key set, applied to every home ─────────────────────────────
settings() {
  cat <<EOF
model.provider|$MODEL_PROVIDER
model.default|$MODEL_DEFAULT
model.context_length|$MODEL_CONTEXT_LENGTH
model.api_key|$MODEL_API_KEY
local_runtime.detect_ports|$DETECT_PORTS
compression.max_attempts|$COMPRESSION_MAX_ATTEMPTS
compression.progress_notices|$COMPRESSION_PROGRESS_NOTICES
compression.threshold_tokens|$COMPRESSION_THRESHOLD_TOKENS
agent.local_stream_stale_timeout|$LOCAL_STREAM_STALE_TIMEOUT
auxiliary.goal_judge.timeout|$AUX_TIMEOUT
auxiliary.kanban_decomposer.timeout|$AUX_TIMEOUT
auxiliary.triage_specifier.timeout|$AUX_TIMEOUT
auxiliary.background_review.max_input_tokens|$BACKGROUND_REVIEW_MAX_INPUT_TOKENS
kanban.max_in_progress|$MAX_IN_PROGRESS
kanban.orchestrator_profile|$KANBAN_ORCHESTRATOR_PROFILE
kanban.failure_limit|$KANBAN_FAILURE_LIMIT
kanban.auto_decompose|$KANBAN_AUTO_DECOMPOSE
kanban.review_dispatch|$KANBAN_REVIEW_DISPATCH
hooks_auto_accept|$HOOKS_AUTO_ACCEPT
skills.external_dirs|$SKILLS_EXTERNAL_DIRS
EOF
}

# Current value, for change detection. `hermes config get` is a *human* surface:
#   - absent           -> "Config key not set: X"
#   - string "none"    -> YAML null, prints "null"
#   - a list           -> prints as YAML block lines "  - 58000", not "[58000]"
#   - booleans         -> "True"/"False"
# So both sides go through _norm() before comparing. Without this the check
# reported 16 phantom drifts and could never converge.
_norm() {
  local v
  v=$(printf '%s' "$1" \
    | sed 's/^Config key not set: .*//' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  # YAML block list ("- 58000") -> "[58000]"
  if printf '%s' "$v" | grep -q '^- '; then
    v="["$(printf '%s' "$v" | sed 's/^- //' | paste -sd, -)"]"
  fi
  # null / none / undefined are the same absence to Hermes
  case "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" in
    null|none|undefined|~|'') v="" ;;
  esac
  # booleans
  case "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" in
    true|false) v=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]') ;;
  esac
  printf '%s' "$v"
}

current() { # profile key -> normalised current value
  local p="$1" key="$2" args=()
  [ "$p" != default ] && args=(-p "$p")
  _norm "$(hermes "${args[@]}" config get "$key" 2>/dev/null | tail -1)"
}

changed=0
failed=0

apply_to() { # profile-name  (default = main home)
  local p="$1" key want have w_norm
  while IFS='|' read -r key want; do
    [ -z "$key" ] && continue
    have=$(current "$p" "$key")
    w_norm=$(_norm "$want")
    [ "$have" = "$w_norm" ] && continue

    changed=$((changed + 1))
    if [ "$DRY" = 1 ] || [ "$CHECK" = 1 ]; then
      printf '  %-14s %-38s %s -> %s\n' "$p" "$key" "${have:-<unset>}" "$want"
      continue
    fi
    local args=()
    [ "$p" != default ] && args=(-p "$p")
    if ! out=$(hermes "${args[@]}" config set "$key" "$want" 2>&1); then
      printf '  FAILED %-14s %-38s %s\n' "$p" "$key" "$out"
      failed=$((failed + 1))
    fi
  done < <(settings)
}

echo "profiles: default ${FLEET_PROFILES[*]}"
apply_to default
for p in "${FLEET_PROFILES[@]}"; do
  apply_to "$p"
done

echo
if [ "$CHECK" = 1 ]; then
  if [ "$changed" -gt 0 ]; then
    echo "DRIFT: $changed setting(s) differ from fleet.conf across $(( ${#FLEET_PROFILES[@]} + 1 )) homes."
    exit 1
  fi
  echo "in sync: every home matches fleet.conf"
  exit 0
fi

if [ "$DRY" = 1 ]; then
  echo "dry run: $changed setting(s) would change"
else
  echo "applied: $changed setting(s) changed, $failed failed"
fi
[ "$failed" -gt 0 ] && exit 1
exit 0
