#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

echo "Removing agent-browser config..."
rm -rf "$VOLUME/.config/agent-browser" 2>/dev/null || true
rm -rf "$VOLUME/.agent-browser" 2>/dev/null || true
rm -rf "$VOLUME/.config/opencode/skills/agentcore" 2>/dev/null || true
rm -rf "$VOLUME/.config/opencode/skills/core" 2>/dev/null || true
rm -rf "$VOLUME/.config/opencode/skills/dogfood" 2>/dev/null || true
rm -rf "$VOLUME/.config/opencode/skills/electron" 2>/dev/null || true
rm -rf "$VOLUME/.config/opencode/skills/slack" 2>/dev/null || true
rm -rf "$VOLUME/.config/opencode/skills/vercel-sandbox" 2>/dev/null || true

echo "agent-browser uninstalled successfully"