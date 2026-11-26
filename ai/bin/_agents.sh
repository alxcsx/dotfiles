# Shared helpers for ask and orch (sourced, not invoked directly).

# Resolve short model aliases (currently agy) to CLI model IDs.
# Usage: resolve_model <agent> <model> [effort]
resolve_model() {
  local agent="$1" model="$2" effort="${3:-}"
  [ -n "$model" ] || return 0
  if [ "$agent" != agy ]; then
    printf '%s' "$model"
    return 0
  fi

  local lvl="${effort:-medium}"
  case "$lvl" in
  none | off | minimal) lvl=low ;;
  low | medium | high | xhigh) ;;
  max) lvl=xhigh ;;
  *) lvl=medium ;;
  esac

  local lvl3="$lvl"
  [ "$lvl3" = xhigh ] && lvl3=high

  case "$model" in
  neon) printf 'gemini-4-neon-%s' "$lvl" ;;
  hydrogen) printf 'gemini-4-hydrogen-%s' "$lvl" ;;
  argon) printf 'gemini-4-argon-%s' "$lvl3" ;;
  carbon) printf 'gemini-4-carbon-%s' "$lvl3" ;;
  flash) printf 'gemini-3.8-flash-%s' "$lvl3" ;;
  opus) printf 'claude-opus-5-5-%s' "$lvl3" ;;
  sonnet) printf 'claude-sonnet-5-5-%s' "$lvl3" ;;
  gpt-oss) printf 'gpt-oss-120b-medium' ;;
  *) printf '%s' "$model" ;;
  esac
}

# Pane name: <agent>[-<model>][-<effort>]-<workspace>, max 32 chars (hc limit).
# Usage: pane_name <agent> [model] [effort] [ws]
pane_name() {
  local agent="$1" model="${2:-}" effort="${3:-}" ws="${4:-}" slug=""
  [ -n "$model" ] && slug="$slug-$(printf '%s' "$model" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_\n-' '-')"
  [ -n "$effort" ] && slug="$slug-$(printf '%s' "$effort" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_\n-' '-')"
  [ -n "$ws" ] || ws=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" | tr -c 'A-Za-z0-9_\n-' '-')
  printf '%s%s-%s' "$agent" "$slug" "$ws" | cut -c1-32
}

# Append the agent's model flag to argv[].
append_model_args() {
  local a="$1" m="$2" e="${3:-}"
  [ -n "$m" ] || return 0
  if [ "$a" = feynman ]; then
    echo "ask: feynman does not support :model on the CLI (use 'feynman model set')" >&2
    exit 1
  fi
  argv+=(--model "$(resolve_model "$a" "$m" "$e")")
}

# Append the agent's reasoning/effort flag to argv[].
append_effort_args() {
  local a="$1" e="$2"
  [ -n "$e" ] || return 0
  case "$a" in
  omp)
    [ "$e" = none ] && e=off
    argv+=(--thinking "$e")
    ;;
  claude | agy) argv+=(--effort "$e") ;;
  copilot) argv+=(--reasoning-effort "$e") ;;
  codex) argv+=(-c "model_reasoning_effort=\"$e\"") ;;
  feynman) ;; # feynman has no CLI effort flag
  esac
}
