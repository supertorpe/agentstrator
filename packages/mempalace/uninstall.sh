#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

rm -rf "$VOLUME/.mempalace" 2>/dev/null || true

remove_mcp_from_opencode "$VOLUME" "mempalace" 2>/dev/null || true

echo "mempalace uninstalled successfully"