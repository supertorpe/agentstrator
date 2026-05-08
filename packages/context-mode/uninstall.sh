#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"
OPENCODE_DIR="$VOLUME/.config/opencode"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

echo "Removing context-mode..."

remove_instructions_from_opencode "$VOLUME" "/agentstrator/.config/opencode/context-mode.md" 2>/dev/null || true

remove_mcp_from_opencode "$VOLUME" "context-mode" 2>/dev/null || true

remove_plugin_from_opencode "$VOLUME" "context-mode" 2>/dev/null || true

rm "$OPENCODE_DIR/context-mode.md"

echo "context-mode removed successfully"
