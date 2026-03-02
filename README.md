# OpenClaw Always On

**Keep OpenClaw Gateway running 24/7 on your Mac Mini without manual intervention.**

## The Problem

You installed OpenClaw on a Mac Mini. It's brilliant — handles tasks autonomously, integrates with Telegram, acts as your AI assistant. But there's a critical issue:

**The gateway keeps going down.**

You message OpenClaw. No response. You check the Mac. Gateway crashed. Again. You have to manually restart it. This defeats the entire purpose of having an AI assistant.

**This skill fixes that.**

## The Solution

Automatic recovery system that keeps OpenClaw running 24/7:
- ✅ Auto-restart when gateway crashes (< 10 seconds)
- ✅ Health monitoring every 60 seconds
- ✅ Smart retry logic (3 attempts with backoff)
- ✅ Prevents Mac from sleeping
- ✅ Automatic log rotation
- ✅ Resource monitoring (disk space, port conflicts)

**Result: 99%+ uptime, zero manual intervention.**

## Installation

### The Easy Way (Recommended)

Just send this message to your OpenClaw:

```
Install this skill to keep you running 24/7:
https://github.com/kenny-zheng-best/openclaw-always-on

Run: /openclaw-always-on --prevent-sleep
```

OpenClaw will read the repository, understand what to do, and install the skill itself.

### Manual Installation

```bash
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/kenny-zheng-best/openclaw-always-on.git openclaw-always-on
```

Then in Claude Code:
```
/openclaw-always-on --prevent-sleep
```

## What Gets Installed

Three system services that work together:

1. **Gateway LaunchAgent** — Restarts OpenClaw instantly if it crashes
2. **Watchdog LaunchAgent** — Checks health every 60s, auto-restarts if down
3. **Prevent-Sleep Service** — Keeps your Mac awake 24/7

All three start automatically on boot. No manual intervention needed.

## Quick Status Check

```bash
# Check all services are running
launchctl list | grep openclaw

# Test gateway
curl http://127.0.0.1:18789

# View logs
tail -f ~/.openclaw/logs/gateway.log
```

## Features

### v2.0 Production Ready
- 🔄 **Automatic log rotation** — Compresses logs > 100MB
- 🛡️ **Resource safeguards** — Checks disk space before restart
- ⚡ **Exponential backoff** — Prevents rapid restart loops
- 🔍 **Port conflict detection** — Detects when port 18789 is blocked
- 🔁 **Smart retry logic** — 3 attempts with increasing delays (5s → 10s → 15s)
- 🌐 **Network dependency** — Waits for network before starting
- 📊 **Failure tracking** — Monitors consecutive failures

### Optional: Telegram Notifications

Get notified when OpenClaw goes down or recovers:

```
/openclaw-always-on --prevent-sleep --telegram-bot-token YOUR_TOKEN --telegram-chat-id YOUR_ID
```

Get credentials:
- Bot token: [@BotFather](https://t.me/BotFather)
- Chat ID: [@userinfobot](https://t.me/userinfobot)

## Troubleshooting

### Gateway won't start
```bash
# Check what's wrong
cat ~/.openclaw/logs/gateway.err.log

# Check if port is blocked
lsof -i :18789

# Restart manually
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

### Mac still sleeps
```bash
# Check caffeinate is running
ps aux | grep caffeinate

# Restart sleep prevention
launchctl kickstart -k gui/$(id -u)/ai.openclaw.prevent-sleep
```

### Watchdog not working
```bash
# Test watchdog manually
bash ~/.openclaw/watchdog/gateway-watchdog.sh

# Check logs
tail ~/.openclaw/watchdog/watchdog.log
```

## Requirements

- macOS (LaunchAgent is macOS-specific)
- Node.js installed
- OpenClaw installed
- Claude Code (to run the skill)

## Architecture

```
┌─────────────────────────────────────────┐
│    macOS LaunchAgent (System Level)    │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┼─────────┐
        │         │         │
        ▼         ▼         ▼
    Gateway   Watchdog   Prevent
   (18789)   (Monitor)   Sleep
        │         │         │
        └─────────┼─────────┘
                  │
        ┌─────────▼──────────┐
        │  OpenClaw Running  │
        │    Always On 🦞    │
        └────────────────────┘
```

**Recovery Flow:**
1. Watchdog checks HTTP health every 60s
2. If down → Pre-flight checks (disk space, port conflict)
3. Apply exponential backoff if recent failures
4. Restart via launchctl kickstart
5. Retry up to 3 times with increasing delays
6. Send notifications (macOS + Telegram)

## Documentation

- [CHANGELOG.md](./CHANGELOG.md) — Version history
- [SKILL.md](./SKILL.md) — Technical details for Claude
- [PREVENT-SLEEP.md](./PREVENT-SLEEP.md) — Sleep prevention guide

## Why This Exists

OpenClaw is incredibly capable. But capability without reliability is just frustration.

This skill gives ordinary people what CEOs have: an AI assistant that actually works when you need it. You provide the goals, power, and compute. This skill provides the stability.

**Your AI should work harder than you do. This skill makes sure it can.**

## Stats

**Before this skill:**
- Uptime: 85-90%
- Manual restarts: 2-3 times per week
- Recovery time: Hours (when you notice)

**After this skill:**
- Uptime: 99%+
- Manual restarts: ~0
- Recovery time: < 60 seconds (automatic)

## Contributing

Improvements welcome:
- Linux support (systemd units)
- More notification options (email, Slack)
- Dashboard/status page

## License

MIT — Use freely, modify, share

---

**An AI that's down is just an expensive paperweight. Keep it running.**
