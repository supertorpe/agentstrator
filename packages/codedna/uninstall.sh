#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

rm -f "$VOLUME/.opencode/plugins/codedna.js" 2>/dev/null || true

echo "codedna uninstalled successfully"