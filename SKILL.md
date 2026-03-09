---
name: openclaw-never-die
type: skill
version: 2.0.0
displayName: OpenClaw Never Die
description: Keep OpenClaw Gateway running 24/7 without manual intervention. Auto-recovery system that restarts crashed gateway, monitors health every 60s, prevents Mac from sleeping, and handles log rotation. ALWAYS use this skill when user mentions: OpenClaw downtime, gateway crashes, service reliability, Mac Mini server setup, 24/7 operation, automatic restart, or keeping services alive. Use proactively if you detect the user has OpenClaw installed and might benefit from stability improvements.
argument-hint: "[--telegram-bot-token TOKEN] [--telegram-chat-id ID] [--check-interval SECONDS] [--prevent-sleep]"
disable-model-invocation: false
user-invocable: true
---

# OpenClaw Gateway Auto-Recovery Setup

Sets up three macOS LaunchAgent services that work together to keep OpenClaw Gateway alive 24/7:

1. **Gateway LaunchAgent** - Instant restart on crashes (KeepAlive + 10s throttle + network dependency)
2. **Watchdog LaunchAgent** - HTTP health check every 60s with 3-retry recovery, exponential backoff, disk/port checks
3. **Prevent-Sleep Service** (optional) - caffeinate to keep Mac awake

This skill bundles ready-to-use scripts and templates in `scripts/` and `templates/`. Copy them to the target locations and replace placeholders — do NOT regenerate them from scratch.

## Usage

```
/openclaw-never-die                           # Basic setup
/openclaw-never-die --prevent-sleep           # + keep Mac awake
/openclaw-never-die --telegram-bot-token TOKEN --telegram-chat-id ID  # + notifications
/openclaw-never-die --check-interval 30       # Custom interval (default 60)
```

## Instructions

When this skill is invoked, follow these steps in order. Stop and report if any critical step fails.

### Step 1: Detect Environment

Run these checks and report findings:

```bash
uname -s          # Must be "Darwin" (macOS only)
which node         # Node.js path
which openclaw     # Or check ~/.openclaw/bin/openclaw
echo $SHELL        # zsh or bash
echo $HOME         # Home directory
```

If openclaw is not found at either location, tell the user to install it first and stop.

### Step 2: Parse Arguments

Extract from `$ARGUMENTS`:
- `--telegram-bot-token TOKEN` (optional)
- `--telegram-chat-id ID` (optional)
- `--check-interval SECONDS` (default: 60)
- `--prevent-sleep` flag (optional)

### Step 3: Create Directories

Create all required directories before writing any files:

```bash
mkdir -p ~/.openclaw/logs
mkdir -p ~/.openclaw/watchdog
mkdir -p ~/Library/LaunchAgents
```

### Step 4: Configure PATH

Check if `~/.openclaw/bin` is in PATH via shell config (`~/.zshrc` or `~/.bashrc`).

If not present:
1. Backup the config file
2. Append: `export PATH="$HOME/.openclaw/bin:$PATH"`
3. Tell user to run `source ~/.zshrc` (or restart terminal)

### Step 5: Install Gateway LaunchAgent

Detect the actual paths on this system:

```bash
NODE_PATH=$(which node)
# Find openclaw lib path — the parent of the bin directory
OPENCLAW_BIN=$(which openclaw 2>/dev/null || echo "$HOME/.openclaw/bin/openclaw")
OPENCLAW_LIB=$(dirname "$(dirname "$OPENCLAW_BIN")")/lib
HOME_DIR=$HOME
GATEWAY_PORT=18789
```

Copy the template from this skill's `templates/ai.openclaw.gateway.plist` and replace placeholders:
- `__NODE_PATH__` → value of `$NODE_PATH`
- `__OPENCLAW_LIB_PATH__` → value of `$OPENCLAW_LIB`
- `__HOME_DIR__` → value of `$HOME_DIR`
- `__GATEWAY_PORT__` → `18789`

Write the result to `~/Library/LaunchAgents/ai.openclaw.gateway.plist`.

**KeepAlive behavior in this template:**
- `SuccessfulExit: false` — only restart on crashes, not clean shutdown
- `NetworkState: true` — wait for network before starting
- `ThrottleInterval: 10` — minimum 10s between restarts

### Step 6: Install Watchdog Script

Copy `scripts/gateway-watchdog.sh` from this skill directory to `~/.openclaw/watchdog/gateway-watchdog.sh`.

Replace placeholders in the copied file:
- `__GATEWAY_PORT__` → `18789`
- `__TELEGRAM_BOT_TOKEN__` → the token from arguments, or empty string if not provided
- `__TELEGRAM_CHAT_ID__` → the chat ID from arguments, or empty string if not provided

Make it executable:
```bash
chmod +x ~/.openclaw/watchdog/gateway-watchdog.sh
```

### Step 7: Install Watchdog LaunchAgent

Copy `templates/ai.openclaw.watchdog.plist` and replace:
- `__HOME_DIR__` → `$HOME`
- `__CHECK_INTERVAL__` → value from `--check-interval` argument (default: 60)

Write to `~/Library/LaunchAgents/ai.openclaw.watchdog.plist`.

### Step 8: Install Prevent-Sleep Service (only if --prevent-sleep)

If the `--prevent-sleep` flag was provided:

Copy `templates/ai.openclaw.prevent-sleep.plist` to `~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist` (no placeholders to replace).

For details on sleep prevention options, see `PREVENT-SLEEP.md` in this skill directory.

### Step 9: Load Services

Unload existing services first (ignore errors), then load new ones:

```bash
launchctl bootout gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
launchctl bootout gui/$(id -u)/ai.openclaw.watchdog 2>/dev/null
launchctl bootout gui/$(id -u)/ai.openclaw.prevent-sleep 2>/dev/null

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.watchdog.plist

# Only if --prevent-sleep was used
if [ -f ~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist ]; then
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist
fi
```

### Step 10: Verify

Wait 3 seconds, then check everything works:

```bash
# Services loaded?
launchctl list | grep openclaw

# Gateway listening?
lsof -i :18789

# HTTP health?
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/health
# Expected: 200

# Recent logs
tail -5 ~/.openclaw/logs/gateway.log
tail -5 ~/.openclaw/watchdog/watchdog-stdout.log
```

### Step 11: Show Summary

Report to the user:

```
OpenClaw Auto-Recovery Setup Complete!

Installed:
1. Gateway LaunchAgent (auto-start on boot, auto-restart on crash)
2. Watchdog LaunchAgent (health check every Xs, auto-recovery)
3. Sleep Prevention: [ENABLED/DISABLED]
4. Telegram notifications: [ENABLED/DISABLED]

Status:
- Gateway: RUNNING/DOWN (PID: X, HTTP: 200/xxx)
- Watchdog: RUNNING/DOWN
- Port 18789: LISTENING/NOT LISTENING

Useful commands:
- View logs: tail -f ~/.openclaw/logs/gateway.log
- Check status: launchctl list | grep openclaw
- Restart: launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
- Stop: launchctl bootout gui/$(id -u)/ai.openclaw.gateway

Uninstall:
  launchctl bootout gui/$(id -u)/ai.openclaw.gateway
  launchctl bootout gui/$(id -u)/ai.openclaw.watchdog
  launchctl bootout gui/$(id -u)/ai.openclaw.prevent-sleep
  rm ~/Library/LaunchAgents/ai.openclaw.gateway.plist
  rm ~/Library/LaunchAgents/ai.openclaw.watchdog.plist
  rm ~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist
```

## Error Handling

Common issues and what to do:
- **Not macOS** — This skill uses LaunchAgent, macOS only. Stop and explain.
- **No openclaw** — Tell user to install openclaw first.
- **No node** — Tell user to install Node.js first.
- **Port 18789 in use** — Run `lsof -i :18789` to find the conflict, report to user.
- **LaunchAgent won't load** — Check `~/.openclaw/logs/gateway.err.log` for details.
- **Permission denied** — Ensure scripts are executable (`chmod +x`).

## Bundled Files

```
scripts/
  gateway-watchdog.sh    — Watchdog script (copy to ~/.openclaw/watchdog/, replace placeholders)

templates/
  ai.openclaw.gateway.plist       — Gateway LaunchAgent template
  ai.openclaw.watchdog.plist      — Watchdog LaunchAgent template
  ai.openclaw.prevent-sleep.plist — Sleep prevention LaunchAgent template
```

Placeholders used across files:
| Placeholder | Source | Example |
|---|---|---|
| `__NODE_PATH__` | `which node` | `/opt/homebrew/bin/node` |
| `__OPENCLAW_LIB_PATH__` | Derived from `which openclaw` | `~/.openclaw/lib` |
| `__HOME_DIR__` | `$HOME` | `/Users/username` |
| `__GATEWAY_PORT__` | Hardcoded | `18789` |
| `__CHECK_INTERVAL__` | `--check-interval` arg | `60` |
| `__TELEGRAM_BOT_TOKEN__` | `--telegram-bot-token` arg | (empty if not set) |
| `__TELEGRAM_CHAT_ID__` | `--telegram-chat-id` arg | (empty if not set) |
