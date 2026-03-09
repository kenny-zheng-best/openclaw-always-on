#!/bin/bash
# Test script to verify skill installation and functionality

echo "🧪 OpenClaw Watchdog Skill - Installation Test"
echo "=============================================="
echo ""

SKILL_DIR="$HOME/.claude/skills/openclaw-never-die"
ERRORS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
    local status=$1
    local message=$2
    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
        ((ERRORS++))
    fi
}

# Test 1: Check if skill directory exists
echo "1️⃣  Checking skill installation..."
[ -d "$SKILL_DIR" ]; check $? "Skill directory exists: $SKILL_DIR"

# Test 2: Check required files
echo ""
echo "2️⃣  Checking required files..."
[ -f "$SKILL_DIR/SKILL.md" ]; check $? "SKILL.md found"

[ -f "$SKILL_DIR/README.md" ]; check $? "README.md found"

[ -f "$SKILL_DIR/install.sh" ] && [ -x "$SKILL_DIR/install.sh" ]; check $? "install.sh found and executable"

# Test 3: Validate SKILL.md format
echo ""
echo "3️⃣  Validating SKILL.md format..."
grep -q "^---$" "$SKILL_DIR/SKILL.md"; check $? "YAML frontmatter delimiter found"

grep -q "^name:" "$SKILL_DIR/SKILL.md"; check $? "name field present"

grep -q "^description:" "$SKILL_DIR/SKILL.md"; check $? "description field present"

# Test 4: Check Claude Code installation
echo ""
echo "4️⃣  Checking Claude Code..."
if command -v claude &> /dev/null; then
    check 0 "Claude Code is installed"
    echo "   Version: $(claude --version 2>&1 | head -1)"
else
    echo -e "${YELLOW}⚠${NC} Claude Code not found (this test can be skipped if Claude is installed elsewhere)"
fi

# Test 5: Check system requirements
echo ""
echo "5️⃣  Checking system requirements..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    check 0 "Running on macOS (required)"
else
    echo -e "${RED}✗${NC} Not running on macOS (LaunchAgent requires macOS)"
    ((ERRORS++))
fi

if command -v node &> /dev/null; then
    check 0 "Node.js is installed"
    echo "   Version: $(node --version)"
else
    echo -e "${YELLOW}⚠${NC} Node.js not found (required for OpenClaw)"
fi

if command -v openclaw &> /dev/null || [ -f "$HOME/.openclaw/bin/openclaw" ]; then
    check 0 "OpenClaw is installed"
else
    echo -e "${YELLOW}⚠${NC} OpenClaw not found (skill can still be installed)"
fi

# Test 6: Check if skill is discoverable
echo ""
echo "6️⃣  Checking skill discoverability..."
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    SKILL_NAME=$(grep "^name:" "$SKILL_DIR/SKILL.md" | cut -d: -f2 | tr -d ' ')
    check $? "Skill name extracted: $SKILL_NAME"
fi

# Summary
echo ""
echo "==========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Start Claude Code: claude"
    echo "   2. Run the skill: /$SKILL_NAME"
    echo ""
    echo "📚 Documentation:"
    echo "   - README: $SKILL_DIR/README.md"
    echo "   - Sharing: $SKILL_DIR/SHARING.md"
else
    echo -e "${RED}✗ $ERRORS test(s) failed${NC}"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   1. Ensure all files are in: $SKILL_DIR"
    echo "   2. Run install script: ./install.sh"
    echo "   3. Check Claude Code installation"
fi
echo "==========================================="
