#!/usr/bin/env bash
# install.sh — install the sudo-approve queue in one command. Run it from your own shell:
#
#     bash ~/dotfiles/arch_server/sudo-queue/install.sh            # install / update
#     bash ~/dotfiles/arch_server/sudo-queue/install.sh --check    # verify, change nothing
#
# It asks for three things and never echoes the token back: a bot token from @BotFather,
# your numeric Telegram id, and (once) your sudo password.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
HERE=$(pwd)
ENVF=/etc/sudo-approve/env
UNIT=/etc/systemd/system/sudo-approve.service
QUEUE=${SUDO_APPROVE_DIR:-$HOME/.local/state/sudo-queue}
MODE=${1:-install}

ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; }
note() { printf '  ..   %s\n' "$*"; }

echo "sudo-approve installer — queue at $QUEUE"
echo

# ---------- checks that need no root ----------
rc=0
for f in sudo-approve.py sudo-approve.service sudo-queue; do
  if [ -f "$HERE/$f" ]; then ok "found $f"; else bad "missing $f (run from the repo)"; rc=1; fi
done
if command -v python3 >/dev/null; then ok "python3 $(python3 -V 2>&1 | cut -d' ' -f2)"; else bad "no python3"; rc=1; fi
if command -v systemctl >/dev/null; then ok "systemd present"; else bad "no systemd"; rc=1; fi
if python3 "$HERE/sudo-approve.py" --selftest >/dev/null 2>&1; then
  ok "selftest passes (parser + traversal guard)"
else
  bad "selftest failed — do not install"; rc=1
fi
if mkdir -p "$QUEUE/done" 2>/dev/null; then ok "queue dir writable: $QUEUE"; else bad "cannot create $QUEUE"; rc=1; fi

if [ "$MODE" = "--check" ]; then
  echo
  if [ $rc = 0 ]; then echo "ready to install"; else echo "not ready"; fi
  exit $rc
fi
if [ $rc != 0 ]; then echo; echo "fix the above first"; exit 1; fi

# ---------- credentials ----------
echo
echo "1) Bot token — create a NEW bot with @BotFather (/newbot). Do not reuse the Hermes token."
printf '   token: '
read -rs TOKEN; echo
if ! [[ $TOKEN =~ ^[0-9]{6,12}:[A-Za-z0-9_-]{30,}$ ]]; then
  bad "that does not look like a bot token (expected 123456:AA...)"
  exit 1
fi
ok "token shape looks right"

echo "2) Your numeric id — message @userinfobot on Telegram."
printf '   operator id: '
read -r OPERATOR
if ! [[ $OPERATOR =~ ^[0-9]{5,15}$ ]]; then
  bad "operator id must be numeric"
  exit 1
fi
ok "operator ${OPERATOR}"

# ---------- install (asks for sudo once) ----------
echo
echo "3) Installing — sudo will ask for your password now."
sudo -v || { bad "sudo failed"; exit 1; }
{
  sudo install -d -m 700 /etc/sudo-approve &&
    printf 'SUDO_APPROVE_TOKEN=%s\nSUDO_APPROVE_OPERATOR=%s\nSUDO_APPROVE_DIR=%s\n' \
      "$TOKEN" "$OPERATOR" "$QUEUE" | sudo tee "$ENVF" >/dev/null &&
    sudo chmod 600 "$ENVF" &&
    sudo install -m 644 "$HERE/sudo-approve.service" "$UNIT" &&
    sudo systemctl daemon-reload &&
    sudo systemctl enable sudo-approve >/dev/null 2>&1 &&
    sudo systemctl restart sudo-approve
} || { bad "install step failed"; exit 1; }
ok "unit installed and started"

sleep 3
if systemctl is-active --quiet sudo-approve; then
  ok "service active"
else
  bad "service is not active — journal:"
  sudo journalctl -u sudo-approve -n 20 --no-pager
  exit 1
fi
if sudo journalctl -u sudo-approve -n 40 --no-pager 2>/dev/null | grep -q "sudo-approve up:"; then
  ok "service reports its queue and operator"
else
  note "service is up but its banner is not in the journal yet (may just be lag)"
fi

# ---------- smoke test ----------
echo
echo "4) Queuing a smoke test."
"$HERE/sudo-queue" add "smoke test: print the kernel; safe, changes nothing" >/dev/null <<'SH'
uname -a
SH
QID=$(basename "$(ls -t "$QUEUE"/*.sh 2>/dev/null | head -1)" .sh 2>/dev/null)
echo "   On Telegram, in the new bot:"
echo "     /pending       → see it waiting"
echo "     /show $QID    → read the exact script"
echo "     /run  $QID    → expect ✅ exit 0 plus the uname output"
echo
echo "   Nothing arrives? Wrong token or id:  sudo journalctl -u sudo-approve -n 30 --no-pager"
echo "   Uninstall:  sudo systemctl disable --now sudo-approve && sudo rm $UNIT $ENVF"
