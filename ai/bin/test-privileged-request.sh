#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
output=$("$root/ai/bin/privileged-request" check)
case "$(uname -s)" in
Darwin) expected='macOS: native administrator dialog available' ;;
Linux) expected='Linux: (Polkit dialog|headless Telegram approval queue) available' ;;
*) expected='available' ;;
esac
grep -Eq "$expected" <<<"$output"

link_dir=$(mktemp -d)
queue=
trap 'rm -rf "$link_dir" "$queue"' EXIT
ln -s "$root/ai/bin/privileged-request" "$link_dir/privileged-request"
output=$("$link_dir/privileged-request" check)
grep -Eq "$expected" <<<"$output"

if "$root/ai/bin/privileged-request" run "empty" </dev/null 2>/dev/null; then
  exit 1
fi

queue=$(mktemp -d)
output=$(printf 'id\n' | OSTYPE=linux-gnu SUDO_QUEUE_DIR="$queue" PATH="/usr/bin:/bin" "$root/ai/bin/privileged-request" run "test queue")
grep -q '^queued ' <<<"$output"
test -f "$queue"/*.sh
