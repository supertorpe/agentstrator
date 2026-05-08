#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

echo "Removing openspec..."

rm -f "$VOLUME/.config/opencode/commands"/opsx-*.md
rm -rf "$VOLUME/.config/opencode/skills"/openspec-* 2>/dev/null || true


echo "openspec uninstalled successfully"