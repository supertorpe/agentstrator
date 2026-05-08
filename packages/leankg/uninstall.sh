#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

remove_mcp_from_opencode "$VOLUME" "leankg" 2>/dev/null || true

remove_plugin_from_opencode "$VOLUME" "leankg@git+https://github.com/FreePeak/LeanKG.git" 2>/dev/null || true

rm -rf "$VOLUME/.config/opencode/skills/using-leankg" 2>/dev/null || true

echo "leankg uninstalled successfully"