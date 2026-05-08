#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

rm -rf "$VOLUME/.cache/ms-playwright" 2>/dev/null || true
rm -rf "$VOLUME/.config/google-chrome-for-testing" 2>/dev/null || true
rm -rf "$VOLUME/.config/opencode/skills/playwright-cli" 2>/dev/null || true
rm -rf "$VOLUME/.playwright" 2>/dev/null || true
rm -f "$VOLUME/.playwright-cli-config.json" 2>/dev/null || true

echo "playwright-cli uninstalled successfully"