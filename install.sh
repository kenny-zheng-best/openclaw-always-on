#!/bin/bash
# OpenClaw Never Die - Skill Installer
# Installs the skill into Claude Code / OpenClaw skill directory

set -e

SKILL_NAME="openclaw-never-die"
SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"

echo "OpenClaw Auto-Recovery Skill Installer"
echo "======================================="
echo ""

# Check if Claude Code is installed
if ! command -v claude &> /dev/null; then
    echo "Claude Code not found. Please install Claude Code first:"
    echo "  https://claude.ai/download"
    exit 1
fi

echo "Claude Code detected"
echo ""

# Check if skill already exists
if [ -d "$SKILL_DIR" ]; then
    read -p "Skill already exists. Overwrite? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    echo "Removing existing skill..."
    rm -rf "$SKILL_DIR"
fi

# Determine source directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create skill directory structure
mkdir -p "$SKILL_DIR/scripts"
mkdir -p "$SKILL_DIR/templates"

# Copy essential skill files
echo "Installing skill files..."
for f in SKILL.md README.md CHANGELOG.md PREVENT-SLEEP.md prevent-sleep.sh install.sh test.sh LICENSE; do
    [ -f "$SCRIPT_DIR/$f" ] && cp "$SCRIPT_DIR/$f" "$SKILL_DIR/"
done

# Copy bundled scripts and templates
[ -d "$SCRIPT_DIR/scripts" ] && cp "$SCRIPT_DIR/scripts/"* "$SKILL_DIR/scripts/" 2>/dev/null
[ -d "$SCRIPT_DIR/templates" ] && cp "$SCRIPT_DIR/templates/"* "$SKILL_DIR/templates/" 2>/dev/null

# Make scripts executable
chmod +x "$SKILL_DIR/scripts/"*.sh 2>/dev/null
chmod +x "$SKILL_DIR/prevent-sleep.sh" 2>/dev/null

# Verify installation
if [ -f "$SKILL_DIR/SKILL.md" ] && [ -f "$SKILL_DIR/scripts/gateway-watchdog.sh" ]; then
    echo "Skill installed successfully!"
    echo ""
    echo "Location: $SKILL_DIR"
    echo ""
    echo "Usage:"
    echo "  1. Start a new Claude Code session"
    echo "  2. Run: /openclaw-never-die --prevent-sleep"
    echo ""
    echo "With Telegram notifications:"
    echo "  /openclaw-never-die --telegram-bot-token YOUR_TOKEN --telegram-chat-id YOUR_CHAT_ID --prevent-sleep"
    echo ""
    echo "More info: $SKILL_DIR/README.md"
else
    echo "Installation failed - required files not found"
    exit 1
fi
