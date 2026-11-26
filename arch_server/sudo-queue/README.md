# sudo-queue / sudo-approve — privileged work that only the human can run

The agent never gets sudo. When something needs root it *parks* a script here, and a
separate root-owned bot asks **you** on Telegram. Nothing executes until you reply
`/run <id>` from your own account. The agent has the *Hermes* bot token; this bot has its
own token, so the agent cannot send you a message as if it were the approver, and it cannot
reply as you.

```
agent (as alex, no sudo)                 root                       you (Telegram)
  sudo-queue add "why"  ──►  ~/.local/state/sudo-queue/<id>.sh
                                    │
                            sudo-approve.service ──► "🔐 1 script waiting"
                                                          │
                                              /show <id>  │  (you read the script)
                                              /run  <id> ─┘  → runs as root, output back
```

## Install (needs your password; the agent cannot do this)

1. **A new bot.** Talk to [@BotFather](https://t.me/BotFather) → `/newbot` → name it
   something like `derby-sudo` → copy the token. Do **not** reuse the Hermes bot's token:
   the whole design is that the agent holds that one and must not hold this one.
2. **Your numeric id.** Message [@userinfobot](https://t.me/userinfobot), copy the id.
3. **Config**, root-only:

   ```bash
   sudo install -d -m 700 /etc/sudo-approve
   sudo tee /etc/sudo-approve/env >/dev/null <<'EOF'
   SUDO_APPROVE_TOKEN=<token from BotFather>
   SUDO_APPROVE_OPERATOR=<your numeric id>
   SUDO_APPROVE_DIR=/home/alex/.local/state/sudo-queue
   EOF
   sudo chmod 600 /etc/sudo-approve/env
   ```

4. **Service**:

   ```bash
   sudo install -m 644 ~/dotfiles/arch_server/sudo-queue/sudo-approve.service \
        /etc/systemd/system/sudo-approve.service
   sudo systemctl daemon-reload
   sudo systemctl enable --now sudo-approve
   systemctl status sudo-approve --no-pager | head -5
   journalctl -u sudo-approve -f          # watch it poll
   ```

5. **Verify end to end** — queue something harmless and run it from the phone:

   ```bash
   sudo-queue add "smoke test: print the kernel" <<'SH'
   uname -a
   SH
   ```

   Then in the bot: `/pending`, `/show <id>`, `/run <id>`. Expect `✅ <id> — exit 0` and the
   `uname` output. Files land in `~/.local/state/sudo-queue/done/` next to `audit.log`.

## Commands the bot accepts

| command | what |
|---|---|
| `/pending` | ids + one-line reasons |
| `/show <id>` | the exact script, verbatim |
| `/run <id>` | executes as root via `bash`, 300 s timeout, output returned |
| `/deny <id>` | drops it |

Anything else is ignored. Messages from any other Telegram account are dropped and logged.

## For agents

Add, never approve:

```bash
sudo-queue add "raise zram to 8 GiB; 3.6/4.0 used with 20 GiB RAM free" <<'SH'
printf '[zram0]\nzram-size = 8192\ncompression-algorithm = zstd\n' | tee /etc/systemd/zram-generator.conf
systemctl daemon-reload && systemctl restart systemd-zram-setup@zram0.service
SH
```

Rules that keep this honest:

- **One concern per queue item.** The human reads it before running; a script that does
  five things cannot be reviewed.
- **Make it idempotent and reversible.** Say in the `why` line how to undo it.
- Scripts run as root with root's `PATH` and `cd /root` — use absolute paths, and do not
  assume `~/.local/bin` (that is alex's).
- Do not queue anything that needs a decision from the human mid-run; it has no TTY.
- `/etc/systemd/network/*` is not a good queue item: a bad edit cuts the uplink and locks
  the box out. Anything that can sever remote access is a human-at-the-console job.

## Threat model, stated plainly

- **The token must not be the Hermes one.** The agent runs as `alex` and can read
  `~/.hermes/.env` (the Hermes bot token lives there). And one bot token is one update
  stream: Telegram hands each update to a single consumer and the offset acknowledges it for
  everyone — so a second long-poller on that token sits in `409 Conflict` while the gateway
  polls, and otherwise steals updates at random (`/run` replies would vanish into the chat
  stream and vice versa). A separate token is what makes the approval channel unreadable,
  unwriteable and un-swallowable by the agent. The approval factor is still the operator's
  *account*, not the token.
- The agent can **add** any script. That is inert until you type `/run`.
- The agent cannot approve: approval requires a message from your Telegram account, and the
  bot's token does not exist anywhere the agent can read.
- A leaked bot token alone is not enough either: without your `OPERATOR_ID` account sending
  the command, the bot drops the message.
- What is *not* protected: you running something you did not read. `/show` exists for that.

Selftest (no network, no token): `python3 sudo-approve.py --selftest`
