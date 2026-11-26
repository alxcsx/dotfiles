#!/usr/bin/env bash
# maintenance-scan.sh — deterministic weekly hygiene scan. Feeds the Monday cron job.
#
# WHY: the expensive part of a maintenance run on this box is the agent *looking* for
# problems (every tool call re-sends a ~15k-token prompt). So the looking happens here,
# once, in shell; the agent only triages what this prints and files kanban cards.
#
# Every check below has caught a real problem on this box at least once. Nothing
# speculative: no "consider tuning X" lines, only measured facts with a fix attached.
#
# Output: one line per finding, "SEV ID — detail". Nothing found = one CLEAN line.
# Exit code is always 0 (the cron job reads stdout, not status).
set -uo pipefail
H=$HOME
emit() { printf '%-4s %-20s %s\n' "$1" "$2" "$3"; }
found=0
f() { found=1; emit "$@"; }

# --- 0. the rulebook has to fit in the prompt: Hermes truncates context files at 20000
# chars and silently drops the tail (it had been hiding the Rules section for months).
ac=$(wc -c < "$H/AGENTS.md" 2>/dev/null || echo 0)
[ "${ac:-0}" -gt 19500 ] && f WARN agents-md-too-long "AGENTS.md is $ac chars; the prompt builder truncates at 20000 and drops the tail silently — trim it"

# --- 1. fleet availability (services, model, disk, tailnet, board, cron staleness).
# Silent when healthy; fleet-notify already paged you if it is not.
out=$(timeout 120 python3 "$H/dotfiles/ai/hermes/fleet-check.py" 2>&1)
[ -n "$out" ] && f FAIL fleet-check "$(tr '\n' ' ' <<<"$out" | cut -c1-400)"

# --- 2. processes nobody owns: (a) listening sockets with no unit and no container
# (same derivation `svc` uses), (b) anything still running in a session logind no
# longer lists. Found 4 orphans holding 537 MB on 2026-11-07, all of them listeners.
stray=$(svc 2>/dev/null | grep '^stray listeners' | sed 's/^stray listeners[^:]*: //')
[ -n "$stray" ] && f WARN stray-listeners "hand-started, no unit/container: $stray"
live=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}' | sort -u)
orphs=""
while read -r id; do
  grep -qx "$id" <<<"$live" && continue
  for p in $(grep -l "/session-$id\.scope\b" /proc/[0-9]*/cgroup 2>/dev/null | cut -d/ -f3); do
    orphs+="$(ps -o comm= -p "$p" 2>/dev/null)#$p "
  done
done < <(cat /proc/[0-9]*/cgroup 2>/dev/null | grep -oE 'session-[0-9]+' | cut -d- -f2 | sort -u)
[ -n "$orphs" ] && f WARN dead-session-procs "still running from a login logind no longer tracks: $orphs"

# --- 3. zram full while RAM is free: the model then faults pages back from swap.
read -r zused ztotal < <(free -m | awk '/^Swap:/{print $3, $2}')
avail=$(awk '/^MemAvailable:/{print int($2/1024)}' /proc/meminfo)
if [ "$ztotal" -gt 0 ] && [ $((zused * 100 / ztotal)) -gt 80 ] && [ "$avail" -gt 4096 ]; then
  f WARN zram-undersized "swap ${zused}/${ztotal} MiB used with ${avail} MiB RAM available; raise zram-size in /etc/systemd/zram-generator.conf (sudo)"
fi
swapped=$(for x in /proc/[0-9]*/status; do awk '/^Name:/{n=$2} /^VmSwap:/{if($2>200000) print n"("int($2/1024)"M)"}' "$x" 2>/dev/null; done | sort -u | paste -sd' ')
[ -n "$swapped" ] && f INFO heavy-swap "processes with >200 MB in zram: $swapped"

# --- 4. container storage leak: every deploy leaves its previous layer set dangling.
dang=$(podman images -f dangling=true -q 2>/dev/null | wc -l)
buildah=$(podman ps -a --external --format '{{.ID}}|{{.Status}}' 2>/dev/null | awk -F'|' '$2=="Storage"' | wc -l)
if [ "$dang" -gt 20 ] || [ "$buildah" -gt 0 ]; then
  f WARN image-leak "$dang dangling images, $buildah buildah containers stuck in Storage (fix: podman image prune -f; the CD script prunes after each healthy deploy)"
fi

# --- 5. backup age. A missing snapshot is only discovered when you need one.
if [ -r "$H/.config/restic/password" ]; then
  last=$(RESTIC_PASSWORD_FILE=$H/.config/restic/password timeout 90 \
    restic -r rclone:gdrive:Backups/derby snapshots --latest 1 --json 2>/dev/null |
    python3 -c 'import json,sys; s=json.load(sys.stdin); print(max(x["time"] for x in s)[:19] if s else "none")' 2>/dev/null)
  if age=$(( ( $(date +%s) - $(date -d "${last:-1970-01-01}" +%s) ) / 3600 )); then
    [ "$age" -gt 36 ] && f FAIL backup-stale "newest restic snapshot is ${age} h old ($last); check journalctl --user -u backup"
  fi
else
  f WARN backup-unknown "no ~/.config/restic/password — cannot verify the backup age"
fi

# --- 6. DDNS: a stale A record silently breaks the public Minecraft door.
real_ip=$(curl -4 -s -m 10 https://api.ipify.org 2>/dev/null)
rec_ip=$(journalctl --user -u cloudflare-ddns -n 20 -o cat --no-pager 2>/dev/null | grep -oE '\-> [0-9.]+' | tail -1 | awk '{print $2}')
[ -n "$real_ip" ] && [ -n "$rec_ip" ] && [ "$real_ip" != "$rec_ip" ] &&
  f WARN ddns-stale "public IP $real_ip but the A record says $rec_ip (journalctl --user -u cloudflare-ddns)"

# --- 7. IPv6 blackholes some destinations; the Telegram gateway then stalls on every send.
rewalks=$(journalctl --user -u hermes-gateway --since "-24h" -o cat --no-pager 2>/dev/null | grep -c "re-walking IPv4")
[ "${rewalks:-0}" -gt 5 ] && f WARN ipv6-telegram "$rewalks IPv4 re-walks / 24 h in hermes-gateway: AAAA attempts hang on the Telegram path"

# --- 8. failed system units, minus the three that fail because Secure Boot is off.
sysfailed=$(systemctl --failed --no-legend --plain 2>/dev/null | grep -vE "pcrlogin|pcrproduct|tpm2-setup" | awk '{print $1}' | paste -sd' ')
[ -n "$sysfailed" ] && f WARN system-units "failed: $sysfailed"

# --- 9. memory + OOM.
oom=$(journalctl -k --since "-7d" --no-pager 2>/dev/null | grep -ciE "out of memory|oom-kill")
[ "${oom:-0}" -gt 0 ] && f FAIL oom "$oom OOM event(s) in 7 d"
disk=$(df --output=pcent / | tail -1 | tr -dc 0-9)
[ "${disk:-0}" -gt 85 ] && f WARN disk "${disk}% used on /"

# --- 10. login sessions nobody closed. They are what leaves orphans behind.
sess=$(loginctl list-sessions --no-legend 2>/dev/null | wc -l)
[ "$sess" -gt 8 ] && f INFO stale-sessions "$sess login sessions open; KillUserProcesses is unset, so anything started in them survives the terminal"

# --- 11. exoforge: deployed commit vs origin, and containers older than the image.
REPO=$H/services/exoforge
if [ -d "$REPO/.git" ]; then
  head=$(git -C "$REPO" rev-parse HEAD 2>/dev/null)
  origin=$(git -C "$REPO" rev-parse origin/projetao_mvp 2>/dev/null)
  [ -n "$origin" ] && [ "$head" != "$origin" ] &&
    f WARN exoforge-behind "checkout at ${head:0:7} but origin/projetao_mvp at ${origin:0:7} (exoforge-cd.timer runs every 5 min — check its log)"
  for n in 1 2 3 4; do
    curl -fsS -m 3 -o /dev/null "http://127.0.0.1:4${n}05/health" || f WARN "exoforge$n-down" "no /health on 127.0.0.1:4${n}05"
  done
fi

# --- 12. kanban hygiene: cards parked past their usefulness.
if csv=$(hermes kanban list --json 2>/dev/null); then
  python3 - "$csv" <<'PY' 2>/dev/null
import json,sys,time
rows=json.loads(sys.argv[1]); rows=rows if isinstance(rows,list) else rows.get("tasks",[])
now=time.time()
for t in rows:
    st,ts=t.get("status"),t.get("updated_at") or t.get("created_at") or 0
    if ts>1e12: ts/=1000
    age=(now-ts)/3600 if ts else 0
    if st=="review" and age>6: print(f"WARN {'board-review-stuck':20} {t.get('id')} in review for {age:.0f} h (review_dispatch is off: the reviewer is you)")
    elif st=="blocked" and age>24: print(f"INFO {'board-blocked':20} {t.get('id')} blocked {age:.0f} h: {(t.get('title') or '')[:60]}")
PY
elif true; then :; fi

[ "$found" -eq 0 ] && echo "CLEAN — no findings: units, zram, container storage, backup, DDNS, telegram path, board all normal."
exit 0
