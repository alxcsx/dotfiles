# Shared helpers for ask and orch (sourced, not invoked directly).

# Resolve short model aliases (agy and local-ai omp models) to CLI model IDs.
# Usage: resolve_model <agent> <model> [effort]
resolve_model() {
  local agent="$1" model="$2" effort="${3:-}"
  [ -n "$model" ] || return 0
  if [ "$agent" = omp ]; then
    case "$model" in
    local-code | local-general | local-fast) printf 'llamacpp/%s' "$model" ;;
    *) printf '%s' "$model" ;;
    esac
    return 0
  fi
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

# Append safe sandbox and approval defaults to argv[].
# Usage: append_permission_args <agent> <interactive|headless|readonly> [spec_file]
append_permission_args() {
  local a="$1" mode="${2:-interactive}" spec="${3:-}"
  case "$a" in
  codex)
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}"
    case "$mode" in
    readonly) argv+=(-s read-only -a never) ;;
    headless)
      argv+=(-s workspace-write -a never)
      [ -d "$state_dir" ] && argv+=(--add-dir "$state_dir")
      ;;
    *)
      argv+=(-s workspace-write --approve-for-me)
      [ -d "$state_dir" ] && argv+=(--add-dir "$state_dir")
      ;;
    esac
    ;;
  copilot)
    # Direct sudo is always blocked; git push is left to agent-gate so the
    # orchestrator can review and approve it.
    argv+=(--sandbox --assisted-approval --deny-tool="shell(sudo:*)")
    if [ "$mode" = readonly ]; then
      argv+=(--deny-tool="write")
    elif [ -n "$spec" ] && [ -f "$spec" ] && command -v jq >/dev/null 2>&1; then
      local file_count f
      file_count=$(jq -r '(.files // []) | length' "$spec" 2>/dev/null || echo 0)
      if [ "$file_count" -eq 0 ]; then
        argv+=(--deny-tool="write")
      else
        while IFS= read -r f; do
          [ -n "$f" ] && argv+=(--allow-tool="write($f)")
        done < <(jq -r '(.files // [])[]' "$spec" 2>/dev/null || true)
      fi
    fi
    ;;
  esac
}

# Build a clean environment array (`clean_env_args`) for `hc run env ...`,
# forwarding user/XDG/toolchain vars while stripping terminal/session identity
# and stray metered API keys.
build_clean_env() {
  local var
  clean_env_args=()
  while IFS= read -r var; do
    case "$var" in
    HC_TERMINAL_ID | TERM | TERM_* | SHLVL | PWD | OLDPWD | _ | \
      ITERM_* | KITTY_* | WEZTERM_* | ALACRITTY_* | TMUX* | ZELLIJ* | \
      ANTIGRAVITY_* | __CF* | __MISE_ORIG_PATH | Apple_PubSub_* | \
      LaunchInstanceID | SECURITYSESSIONID | COMMAND_MODE | \
      ASK_PARENT | ASK_READONLY | ASK_SPEC_FILES | \
      OPENAI_API_KEY | GEMINI_API_KEY)
      continue
      ;;
    esac
    clean_env_args+=("$var=${!var}")
  done < <(compgen -e)
}

# Query a single field from `hc get <target> --json` using jq.
hc_get_field() {
  local target="$1" field="$2"
  if command -v jq >/dev/null 2>&1; then
    hc get "$target" --json 2>/dev/null | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null || true
  else
    hc get "$target" --json 2>/dev/null | sed -n "s/.*\"$field\":\"\\([^\"]*\\)\".*/\\1/p" | head -n1 || true
  fi
}

# Run a command with kernel-level PR_SET_NO_NEW_PRIVS on Linux when the task
# does not declare sudo needs (or when sudo-queue handles root requests).
exec_with_no_new_privs() {
  local allow_setuid="${1:-0}"
  shift
  if [ "$allow_setuid" = 0 ] && [ "$(uname -s)" = Linux ] && command -v python3 >/dev/null 2>&1; then
    exec python3 -c '
import ctypes, os, sys
try:
    ctypes.CDLL("libc.so.6").prctl(38, 1, 0, 0, 0)
except Exception:
    pass
os.execvp(sys.argv[1], sys.argv[1:])
' "$@"
  fi
  exec "$@"
}

# Programmatic quota routing: if omp is exhausted and no model was pinned,
# fall back to hy4-flash-free; if another agent is marked `wait`, warn on stderr.
apply_quota_routing() {
  local quota_bin="$1" agent="$2"
  [ -x "$quota_bin" ] || return 0
  local line state route
  line=$("$quota_bin" 2>/dev/null | awk -v a="$agent" '$1 == a { print $2, $3; exit }' || true)
  [ -n "$line" ] || return 0
  read -r state route <<<"$line"
  if [ "$agent" = omp ] && [ "$state" = out ] && [ -z "${model:-}" ]; then
    model="hy4-flash-free"
    echo "ask: omp quota exhausted; routing to free model '$model'" >&2
  elif [ "$route" = wait ]; then
    echo "ask: warning — '$agent' quota is marked out/wait ($("$quota_bin" 2>/dev/null | awk -v a="$agent" '$1==a{print substr($0, index($0,$4))}'))" >&2
  fi
}
