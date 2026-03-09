#!/bin/bash
# Package script for easy sharing of OpenClaw Watchdog Skill

set -e

SKILL_NAME="openclaw-never-die"
VERSION="1.0.0"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PACKAGE_NAME="${SKILL_NAME}-${VERSION}-${TIMESTAMP}"

echo "📦 Packaging OpenClaw Auto-Recovery Skill"
echo "=========================================="
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Create temp packaging directory
TEMP_DIR=$(mktemp -d)
PKG_DIR="$TEMP_DIR/$SKILL_NAME"

echo "📂 Copying files..."
mkdir -p "$PKG_DIR"
cp -r "$SKILL_NAME"/* "$PKG_DIR/"

# Create version file
echo "$VERSION" > "$PKG_DIR/VERSION"
echo "$(date)" >> "$PKG_DIR/VERSION"

# Create checksums
echo "🔐 Creating checksums..."
cd "$PKG_DIR"
find . -type f ! -name "SHA256SUMS" -exec sha256sum {} \; > SHA256SUMS

# Create archive
echo "🗜️  Creating archive..."
cd "$TEMP_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" "$SKILL_NAME/"

# Move to Desktop for easy access
DEST="$HOME/Desktop/${PACKAGE_NAME}.tar.gz"
mv "${PACKAGE_NAME}.tar.gz" "$DEST"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Package created successfully!"
echo ""
echo "📦 Location: $DEST"
echo "📊 Size: $(du -h "$DEST" | cut -f1)"
echo ""
echo "🚀 To share:"
echo "   1. Send the .tar.gz file to others"
echo "   2. Recipients extract and run: ./install.sh"
echo ""
echo "💡 Or upload to GitHub:"
echo "   cd $(dirname "$DEST")"
echo "   tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "   cd $SKILL_NAME"
echo "   git init && git add . && git commit -m 'Initial commit'"
echo ""
