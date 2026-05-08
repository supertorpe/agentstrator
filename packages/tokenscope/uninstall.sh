#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

remove_plugin_from_opencode "$VOLUME" "@ramtinj95/opencode-tokenscope" 2>/dev/null || true

rm -f "$VOLUME/.config/opencode/command/tokenscope.md" 2>/dev/null || true

echo "tokenscope uninstalled successfully"