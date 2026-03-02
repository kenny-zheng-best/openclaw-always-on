---
name: openclaw-always-on
description: Keep OpenClaw Gateway running 24/7 without manual intervention. Auto-recovery system that restarts crashed gateway, monitors health every 60s, prevents Mac from sleeping, and handles log rotation. Use this when OpenClaw gateway keeps going down on Mac Mini.
argument-hint: "[--telegram-bot-token TOKEN] [--telegram-chat-id ID] [--check-interval SECONDS] [--prevent-sleep]"
disable-model-invocation: false
user-invocable: true
---

# OpenClaw Gateway Auto-Recovery Setup

This skill sets up a production-ready auto-recovery system for OpenClaw Gateway to prevent downtime issues. It provides multiple layers of protection:

1. **macOS LaunchAgent with Smart KeepAlive** - Instant restart on crashes with throttle protection
2. **Health Check Watchdog** - Monitors HTTP endpoint every 60s with retry logic
3. **Resource Safeguards** - Disk space checks, port conflict detection, exponential backoff
4. **Automatic Log Management** - Rotates and compresses logs to prevent disk issues
5. **Optional Telegram Notifications** - Get notified when issues occur and recover
6. **Optional Sleep Prevention** - Keeps Mac awake 24/7 for continuous operation

## What This Skill Does

1. Detects system environment (macOS required, checks for node and openclaw)
2. Adds openclaw to PATH if needed (modifies ~/.zshrc or ~/.bashrc)
3. Installs/updates LaunchAgent for Gateway with KeepAlive enabled
4. Installs/updates LaunchAgent for Watchdog with health monitoring
5. **Optionally prevents Mac from sleeping** (ensures continuous operation)
6. Configures optional Telegram notifications
7. Starts services and verifies everything works
8. Provides diagnostic information and troubleshooting tips

## Usage

Basic setup (no notifications):
```
/setup-openclaw-watchdog
```

With Telegram notifications:
```
/setup-openclaw-watchdog --telegram-bot-token YOUR_BOT_TOKEN --telegram-chat-id YOUR_CHAT_ID
```

Custom check interval (default 60 seconds):
```
/setup-openclaw-watchdog --check-interval 30
```

With sleep prevention (keeps Mac awake 24/7):
```
/setup-openclaw-watchdog --prevent-sleep
```

Full setup with all options:
```
/setup-openclaw-watchdog --telegram-bot-token TOKEN --telegram-chat-id ID --prevent-sleep
```

## Instructions for Claude

When this skill is invoked:

### Step 1: Detect Environment

Check the following and report findings:
- Operating system (must be macOS - LaunchAgent is macOS-specific)
- Node.js installation and version (`which node`)
- OpenClaw installation location (`which openclaw` or `~/.openclaw/bin/openclaw`)
- Current shell (zsh or bash)
- User home directory

If openclaw is not found, provide installation instructions and exit.

### Step 2: Parse Arguments

Extract optional arguments from `$ARGUMENTS`:
- `--telegram-bot-token` - Telegram bot token for notifications
- `--telegram-chat-id` - Telegram chat ID for notifications
- `--check-interval` - Health check interval in seconds (default: 60)
- `--prevent-sleep` - Install caffeinate service to prevent Mac from sleeping

### Step 3: Configure PATH

Check if `~/.openclaw/bin` is in PATH by checking shell config files:
- For zsh: `~/.zshrc`
- For bash: `~/.bashrc` or `~/.bash_profile`

If not present:
1. Backup the shell config file
2. Add the following line (adapt for detected shell):
   ```bash
   export PATH="$HOME/.openclaw/bin:$PATH"
   ```
3. Inform user they need to restart terminal or run `source ~/.zshrc`

### Step 4: Install Gateway LaunchAgent

Create or update `~/Library/LaunchAgents/ai.openclaw.gateway.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>ai.openclaw.gateway</string>

    <key>Comment</key>
    <string>OpenClaw Gateway with Auto-Recovery</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
      <key>SuccessfulExit</key>
      <false/>
      <key>NetworkState</key>
      <true/>
    </dict>

    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>ProgramArguments</key>
    <array>
      <string>NODE_PATH_HERE</string>
      <string>OPENCLAW_LIB_PATH_HERE/node_modules/openclaw/dist/entry.js</string>
      <string>gateway</string>
      <string>--port</string>
      <string>18789</string>
    </array>

    <key>StandardOutPath</key>
    <string>HOME_DIR_HERE/.openclaw/logs/gateway.log</string>

    <key>StandardErrorPath</key>
    <string>HOME_DIR_HERE/.openclaw/logs/gateway.err.log</string>

    <key>EnvironmentVariables</key>
    <dict>
      <key>HOME</key>
      <string>HOME_DIR_HERE</string>
      <key>PATH</key>
      <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
  </dict>
</plist>
```

Replace placeholders:
- `NODE_PATH_HERE` - Result from `which node`
- `OPENCLAW_LIB_PATH_HERE` - Parent of `bin` in openclaw installation (e.g., `~/.openclaw/lib`)
- `HOME_DIR_HERE` - User home directory

**KeepAlive Configuration Explained:**
- `SuccessfulExit: false` - Only restart on abnormal exit (crashes), not on clean shutdown
- `NetworkState: true` - Only start when network is available
- `ThrottleInterval: 10` - Wait 10 seconds between restart attempts (prevents rapid restart loops)

### Step 5: Create Watchdog Script

Create `~/.openclaw/watchdog/gateway-watchdog.sh`:

```bash
#!/bin/bash

GATEWAY_HTTP_URL="http://127.0.0.1:18789"
GATEWAY_PORT="18789"
LOG_FILE="$HOME/.openclaw/watchdog/watchdog.log"
FAILURE_COUNT_FILE="$HOME/.openclaw/watchdog/failure_count"
MAX_LOG_SIZE_MB=100
MIN_DISK_SPACE_GB=2

# Telegram configuration (if provided)
TELEGRAM_BOT_TOKEN="TELEGRAM_TOKEN_HERE"
TELEGRAM_CHAT_ID="TELEGRAM_CHAT_ID_HERE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_telegram() {
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=$1" \
            -d "parse_mode=HTML" > /dev/null 2>&1
    fi
}

notify_macos() {
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"Ping\"" 2>/dev/null
}

# Log rotation - compress and archive if log is too large
rotate_log_if_needed() {
    if [ -f "$LOG_FILE" ]; then
        local log_size_mb=$(du -m "$LOG_FILE" 2>/dev/null | cut -f1)
        if [ "$log_size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            log "📦 Log file too large (${log_size_mb}MB), rotating..."
            mv "$LOG_FILE" "$LOG_FILE.$timestamp"
            gzip "$LOG_FILE.$timestamp" &

            # Keep only last 5 compressed logs
            ls -t "$HOME/.openclaw/watchdog/watchdog.log".*.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
        fi
    fi
}

# Check system resources before attempting restart
check_resources() {
    # Check disk space
    local disk_available=$(df -g / 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$disk_available" ] && [ "$disk_available" -lt "$MIN_DISK_SPACE_GB" ]; then
        log "❌ Critical: Low disk space (${disk_available}GB available)"
        send_telegram "❌ <b>OpenClaw Gateway</b> - Critical: Only ${disk_available}GB disk space left!"
        return 1
    fi

    # Check if system is under heavy load
    local load_avg=$(uptime | awk -F'load averages: ' '{print $2}' | awk '{print $1}' | cut -d. -f1)
    if [ -n "$load_avg" ] && [ "$load_avg" -gt 10 ]; then
        log "⚠️ Warning: High system load ($load_avg), may affect restart"
    fi

    return 0
}

# Check if port is available or used by openclaw
check_port_conflict() {
    local port_user=$(lsof -i :"$GATEWAY_PORT" -sTCP:LISTEN -t 2>/dev/null)
    if [ -n "$port_user" ]; then
        # Port is in use, check if it's openclaw
        if ps -p "$port_user" -o command= | grep -q "openclaw"; then
            # It's openclaw, good
            return 0
        else
            # Port used by another process
            local process_name=$(ps -p "$port_user" -o comm= 2>/dev/null)
            log "❌ Port $GATEWAY_PORT is occupied by another process: $process_name (PID: $port_user)"
            send_telegram "❌ <b>OpenClaw Gateway</b> - Port $GATEWAY_PORT blocked by: $process_name"
            return 1
        fi
    fi
    return 0
}

check_gateway() {
    curl -s --max-time 5 "$GATEWAY_HTTP_URL" > /dev/null 2>&1
}

# Get failure count for backoff strategy
get_failure_count() {
    if [ -f "$FAILURE_COUNT_FILE" ]; then
        cat "$FAILURE_COUNT_FILE"
    else
        echo "0"
    fi
}

# Increment failure count
increment_failure_count() {
    local count=$(get_failure_count)
    echo $((count + 1)) > "$FAILURE_COUNT_FILE"
}

# Reset failure count on success
reset_failure_count() {
    echo "0" > "$FAILURE_COUNT_FILE"
}

# Apply exponential backoff based on failure count
apply_backoff() {
    local count=$(get_failure_count)
    if [ "$count" -gt 0 ]; then
        local wait_time=$((count * 30))
        if [ "$wait_time" -gt 300 ]; then
            wait_time=300  # Max 5 minutes
        fi
        if [ "$wait_time" -gt 0 ]; then
            log "⏳ Applying backoff: waiting ${wait_time}s before restart (failure count: $count)"
            sleep "$wait_time"
        fi
    fi
}

restart_gateway() {
    log "⚠️ Gateway down, restarting..."
    send_telegram "⚠️ <b>OpenClaw Gateway</b> is down, auto-restarting..."

    # Pre-flight checks
    if ! check_resources; then
        increment_failure_count
        return 1
    fi

    if ! check_port_conflict; then
        increment_failure_count
        return 1
    fi

    # Apply backoff if there were recent failures
    apply_backoff

    # Check if LaunchAgent is loaded
    if launchctl list | grep -q "ai.openclaw.gateway"; then
        log "Restarting via LaunchAgent..."
        launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" >> "$LOG_FILE" 2>&1
    else
        log "LaunchAgent not loaded, loading service..."
        launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist >> "$LOG_FILE" 2>&1
    fi

    # Wait for service to start with retry logic
    local max_attempts=3
    local attempt=1
    local wait_time=5

    while [ $attempt -le $max_attempts ]; do
        log "Waiting ${wait_time}s for gateway to start (attempt $attempt/$max_attempts)..."
        sleep "$wait_time"

        if check_gateway; then
            log "✅ Gateway restarted successfully (attempt $attempt)"
            send_telegram "✅ <b>OpenClaw Gateway</b> recovered successfully"
            notify_macos "OpenClaw Gateway" "Gateway recovered successfully"
            reset_failure_count
            return 0
        fi

        attempt=$((attempt + 1))
        wait_time=$((wait_time + 5))  # Increase wait time for next attempt
    done

    # All attempts failed
    log "❌ Restart failed after $max_attempts attempts"
    send_telegram "❌ <b>OpenClaw Gateway</b> restart failed after $max_attempts attempts! Manual intervention needed."
    notify_macos "OpenClaw Gateway" "Restart failed - manual help needed"
    increment_failure_count
    return 1
}

# Main execution
rotate_log_if_needed

if check_gateway; then
    log "✅ Gateway healthy"
    reset_failure_count
    exit 0
else
    restart_gateway
    exit $?
fi
```

Replace `TELEGRAM_TOKEN_HERE` and `TELEGRAM_CHAT_ID_HERE` with values from arguments, or leave empty if not provided.

Make the script executable:
```bash
chmod +x ~/.openclaw/watchdog/gateway-watchdog.sh
```

### Step 6: Install Watchdog LaunchAgent

Create or update `~/Library/LaunchAgents/ai.openclaw.watchdog.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>ai.openclaw.watchdog</string>

    <key>Comment</key>
    <string>OpenClaw Gateway Watchdog - Auto-restart on failure</string>

    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>HOME_DIR_HERE/.openclaw/watchdog/gateway-watchdog.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>HOME_DIR_HERE/.openclaw/watchdog/watchdog-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>HOME_DIR_HERE/.openclaw/watchdog/watchdog-stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
      <key>HOME</key>
      <string>HOME_DIR_HERE</string>
      <key>PATH</key>
      <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>

    <key>ThrottleInterval</key>
    <integer>CHECK_INTERVAL_HERE</integer>
  </dict>
</plist>
```

Replace `HOME_DIR_HERE` and `CHECK_INTERVAL_HERE` (default: 60).

### Step 7: Create Necessary Directories

Ensure directories exist:
```bash
mkdir -p ~/.openclaw/logs
mkdir -p ~/.openclaw/watchdog
```

### Step 8: Install Prevent-Sleep Service (Optional)

If `--prevent-sleep` flag is provided, install a caffeinate service to keep Mac awake:

Create `~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>ai.openclaw.prevent-sleep</string>

    <key>Comment</key>
    <string>Keep Mac awake for OpenClaw Gateway 24/7</string>

    <key>ProgramArguments</key>
    <array>
      <string>/usr/bin/caffeinate</string>
      <string>-dims</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/dev/null</string>

    <key>StandardErrorPath</key>
    <string>/dev/null</string>
  </dict>
</plist>
```

Caffeinate flags explanation:
- `-d` : Prevent display from sleeping
- `-i` : Prevent system from idle sleeping
- `-m` : Prevent disk from sleeping
- `-s` : Prevent system from sleeping on power button

Load the service:
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist
```

**Important Notes:**
- This keeps the Mac awake 24/7, useful for servers (Mac Mini, Mac Studio)
- Display may sleep but system stays awake
- Power consumption will be higher
- For laptops, consider if you really need this
- User can always manually sleep with: `pmset sleepnow`

Also check current power settings:
```bash
pmset -g | grep -E "(sleep|displaysleep)"
```

If user wants permanent system-level changes (requires sudo), note in summary that they can run:
```bash
sudo pmset -a sleep 0          # Disable system sleep
sudo pmset -a displaysleep 0   # Disable display sleep
sudo pmset -a disksleep 0      # Disable disk sleep
```

### Step 9: Load Services

Stop any existing services and load new ones:

```bash
# Unload existing services (ignore errors if not loaded)
launchctl bootout gui/$(id -u)/ai.openclaw.gateway 2>/dev/null
launchctl bootout gui/$(id -u)/ai.openclaw.watchdog 2>/dev/null
launchctl bootout gui/$(id -u)/ai.openclaw.prevent-sleep 2>/dev/null

# Load new services
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.watchdog.plist

# Load prevent-sleep if configured
if [ -f ~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist ]; then
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.prevent-sleep.plist
fi
```

### Step 10: Verify Installation

Wait 3 seconds, then verify:

1. Check services are loaded:
   ```bash
   launchctl list | grep openclaw
   ```
   Should show `ai.openclaw.gateway`, `ai.openclaw.watchdog`, and optionally `ai.openclaw.prevent-sleep`

2. Check gateway is listening on port 18789:
   ```bash
   lsof -i :18789
   ```

3. Check HTTP health:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/health
   ```
   Should return 200

4. Check recent logs:
   ```bash
   tail -10 ~/.openclaw/logs/gateway.log
   tail -10 ~/.openclaw/watchdog/watchdog-stdout.log
   ```

### Step 11: Test Auto-Recovery (Optional)

Offer to test the auto-recovery by killing the gateway process:

```bash
kill $(lsof -i :18789 | grep LISTEN | awk 'NR==1 {print $2}')
sleep 65
tail -10 ~/.openclaw/watchdog/watchdog-stdout.log
curl -s http://127.0.0.1:18789/health
```

Expected: Watchdog should detect the failure within 60s and restart gateway.

### Step 12: Provide Summary

Show a summary with:

```
✅ OpenClaw Auto-Recovery Setup Complete!

📋 What was installed:
1. ✅ Added ~/.openclaw/bin to PATH (restart terminal to apply)
2. ✅ Gateway LaunchAgent (auto-start on boot, auto-restart on crash)
3. ✅ Watchdog LaunchAgent (health check every Xs, auto-recovery)
4. ✅ Sleep Prevention: [ENABLED/DISABLED] (keeps Mac awake 24/7)
5. ✅ Telegram notifications: [ENABLED/DISABLED]

🔧 Current Status:
- Gateway: RUNNING (PID: XXXX, HTTP: 200)
- Watchdog: RUNNING
- Port 18789: LISTENING

📊 Monitoring:
- Health checks: Every Xs
- Logs: ~/.openclaw/logs/ and ~/.openclaw/watchdog/
- Notifications: macOS notifications + [Telegram if configured]

🚀 Auto-Recovery Features:
1. Process crash → Instant restart (macOS KeepAlive with 10s throttle)
2. HTTP health check fails → Auto-restart within 60s (with 3 retry attempts)
3. System reboot → Auto-start on boot (network-dependent)
4. Sleep prevention → Mac stays awake 24/7 (if enabled)
5. Smart safeguards → Disk space check, port conflict detection, exponential backoff
6. Auto log rotation → Compresses logs over 100MB, keeps 5 archives

📝 Useful Commands:
- View gateway logs: tail -f ~/.openclaw/logs/gateway.log
- View watchdog logs: tail -f ~/.openclaw/watchdog/watchdog-stdout.log
- Check service status: launchctl list | grep openclaw
- Restart gateway: launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
- Stop services: launchctl bootout gui/$(id -u)/ai.openclaw.gateway

🛟 Troubleshooting:
If gateway doesn't start:
1. Check logs: ~/.openclaw/logs/gateway.err.log
2. Verify openclaw is installed: which openclaw
3. Check port not in use: lsof -i :18789
4. Manually test: ~/.openclaw/bin/openclaw gateway

If watchdog doesn't work:
1. Check watchdog logs: ~/.openclaw/watchdog/watchdog-stderr.log
2. Test watchdog script manually: bash ~/.openclaw/watchdog/gateway-watchdog.sh
3. Verify LaunchAgent loaded: launchctl list | grep watchdog
```

If Telegram was configured, include:
```
📱 Telegram Setup:
- Bot token: [first 10 chars]...
- Chat ID: XXXXX
- Test notification sent: [check your Telegram]
```

### Error Handling

If any step fails:
1. Report the specific error clearly
2. Show relevant logs or error messages
3. Suggest next steps or alternatives
4. Don't continue if critical steps fail (e.g., openclaw not found)

Common issues to handle:
- **No macOS**: Skill only works on macOS (LaunchAgent is macOS-specific)
- **No openclaw**: Must install openclaw first
- **No node**: Node.js is required
- **Permission denied**: May need to fix permissions on scripts
- **Port already in use**: Another process using port 18789
- **LaunchAgent already loaded**: Unload first before reloading

### Best Practices

1. Always backup existing config files before modifying
2. Use absolute paths in LaunchAgent plist files
3. Create directories before writing files
4. Make scripts executable after creating them
5. Verify each step before proceeding to the next
6. Show clear success/failure indicators
7. Provide actionable next steps

## Files Created/Modified

This skill will create or modify:
- `~/.zshrc` or `~/.bashrc` (adds PATH)
- `~/Library/LaunchAgents/ai.openclaw.gateway.plist` (Gateway service)
- `~/Library/LaunchAgents/ai.openclaw.watchdog.plist` (Watchdog service)
- `~/.openclaw/watchdog/gateway-watchdog.sh` (Watchdog script)
- `~/.openclaw/logs/` (Log directory)
- `~/.openclaw/watchdog/` (Watchdog directory)

All changes are non-destructive and can be reversed by:
```bash
launchctl bootout gui/$(id -u)/ai.openclaw.gateway
launchctl bootout gui/$(id -u)/ai.openclaw.watchdog
rm ~/Library/LaunchAgents/ai.openclaw.gateway.plist
rm ~/Library/LaunchAgents/ai.openclaw.watchdog.plist
# Remove PATH line from shell config manually
```
