#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

rm -f "$VOLUME/.config/opencode/caveman.md" 2>/dev/null || true

remove_instructions_from_opencode "$VOLUME" "/agentstrator/.config/opencode/caveman.md" 2>/dev/null || true

echo "caveman uninstalled successfully"