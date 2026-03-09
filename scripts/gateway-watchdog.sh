#!/bin/bash
# OpenClaw Gateway Watchdog - Health check and auto-recovery
# Installed by openclaw-never-die skill
# Placeholders replaced during installation:
#   __GATEWAY_PORT__        - Gateway port (default: 18789)
#   __TELEGRAM_BOT_TOKEN__  - Telegram bot token (empty if not configured)
#   __TELEGRAM_CHAT_ID__    - Telegram chat ID (empty if not configured)

GATEWAY_HTTP_URL="http://127.0.0.1:__GATEWAY_PORT__"
GATEWAY_PORT="__GATEWAY_PORT__"
LOG_FILE="$HOME/.openclaw/watchdog/watchdog.log"
FAILURE_COUNT_FILE="$HOME/.openclaw/watchdog/failure_count"
MAX_LOG_SIZE_MB=100
MIN_DISK_SPACE_GB=2

TELEGRAM_BOT_TOKEN="__TELEGRAM_BOT_TOKEN__"
TELEGRAM_CHAT_ID="__TELEGRAM_CHAT_ID__"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_telegram() {
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ "$TELEGRAM_BOT_TOKEN" != "__TELEGRAM_BOT_TOKEN__" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=$1" \
            -d "parse_mode=HTML" > /dev/null 2>&1
    fi
}

notify_macos() {
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"Ping\"" 2>/dev/null
}

rotate_log_if_needed() {
    if [ -f "$LOG_FILE" ]; then
        local log_size_mb=$(du -m "$LOG_FILE" 2>/dev/null | cut -f1)
        if [ "$log_size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            log "Log file too large (${log_size_mb}MB), rotating..."
            mv "$LOG_FILE" "$LOG_FILE.$timestamp"
            gzip "$LOG_FILE.$timestamp" &
            ls -t "$HOME/.openclaw/watchdog/watchdog.log".*.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
        fi
    fi
}

check_resources() {
    local disk_available=$(df -g / 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$disk_available" ] && [ "$disk_available" -lt "$MIN_DISK_SPACE_GB" ]; then
        log "Critical: Low disk space (${disk_available}GB available)"
        send_telegram "OpenClaw Gateway - Critical: Only ${disk_available}GB disk space left!"
        return 1
    fi
    local load_avg=$(uptime | awk -F'load averages: ' '{print $2}' | awk '{print $1}' | cut -d. -f1)
    if [ -n "$load_avg" ] && [ "$load_avg" -gt 10 ]; then
        log "Warning: High system load ($load_avg), may affect restart"
    fi
    return 0
}

check_port_conflict() {
    local port_user=$(lsof -i :"$GATEWAY_PORT" -sTCP:LISTEN -t 2>/dev/null)
    if [ -n "$port_user" ]; then
        if ps -p "$port_user" -o command= | grep -q "openclaw"; then
            return 0
        else
            local process_name=$(ps -p "$port_user" -o comm= 2>/dev/null)
            log "Port $GATEWAY_PORT is occupied by: $process_name (PID: $port_user)"
            send_telegram "OpenClaw Gateway - Port $GATEWAY_PORT blocked by: $process_name"
            return 1
        fi
    fi
    return 0
}

check_gateway() {
    curl -s --max-time 5 "$GATEWAY_HTTP_URL" > /dev/null 2>&1
}

get_failure_count() {
    if [ -f "$FAILURE_COUNT_FILE" ]; then cat "$FAILURE_COUNT_FILE"; else echo "0"; fi
}

increment_failure_count() {
    echo $(( $(get_failure_count) + 1 )) > "$FAILURE_COUNT_FILE"
}

reset_failure_count() {
    echo "0" > "$FAILURE_COUNT_FILE"
}

apply_backoff() {
    local count=$(get_failure_count)
    if [ "$count" -gt 0 ]; then
        local wait_time=$((count * 30))
        [ "$wait_time" -gt 300 ] && wait_time=300
        if [ "$wait_time" -gt 0 ]; then
            log "Applying backoff: waiting ${wait_time}s (failure count: $count)"
            sleep "$wait_time"
        fi
    fi
}

restart_gateway() {
    log "Gateway down, restarting..."
    send_telegram "OpenClaw Gateway is down, auto-restarting..."

    check_resources || { increment_failure_count; return 1; }
    check_port_conflict || { increment_failure_count; return 1; }
    apply_backoff

    if launchctl list | grep -q "ai.openclaw.gateway"; then
        log "Restarting via LaunchAgent..."
        launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" >> "$LOG_FILE" 2>&1
    else
        log "LaunchAgent not loaded, loading service..."
        launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist >> "$LOG_FILE" 2>&1
    fi

    local max_attempts=3
    local attempt=1
    local wait_time=5

    while [ $attempt -le $max_attempts ]; do
        log "Waiting ${wait_time}s for gateway (attempt $attempt/$max_attempts)..."
        sleep "$wait_time"
        if check_gateway; then
            log "Gateway restarted successfully (attempt $attempt)"
            send_telegram "OpenClaw Gateway recovered successfully"
            notify_macos "OpenClaw Gateway" "Gateway recovered successfully"
            reset_failure_count
            return 0
        fi
        attempt=$((attempt + 1))
        wait_time=$((wait_time + 5))
    done

    log "Restart failed after $max_attempts attempts"
    send_telegram "OpenClaw Gateway restart failed after $max_attempts attempts! Manual intervention needed."
    notify_macos "OpenClaw Gateway" "Restart failed - manual help needed"
    increment_failure_count
    return 1
}

# Main
rotate_log_if_needed
if check_gateway; then
    log "Gateway healthy"
    reset_failure_count
    exit 0
else
    restart_gateway
    exit $?
fi
