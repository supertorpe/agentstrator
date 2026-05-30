#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

# Source commons.sh for helper functions (remove_plugin_from_opencode, etc.)
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
elif [ -f "$COMPONENT_DIR/../../commons.sh" ]; then
    source "$COMPONENT_DIR/../../commons.sh"
fi

POWER_PACK_DIR="$VOLUME/power-pack"
COMMANDS_DIR="$VOLUME/.config/opencode/commands"

# Remove plugin from opencode.json
remove_plugin_from_opencode "$VOLUME" \
    "opencode-power-pack@git+file:///agentstrator/power-pack" 2>/dev/null || true

# Remove command files that were installed from power-pack
if [ -d "$POWER_PACK_DIR/commands" ]; then
    for f in "$POWER_PACK_DIR/commands/"*.md; do
        [ -f "$f" ] || continue
        cmd_name=$(basename "$f")
        rm -f "$COMMANDS_DIR/$cmd_name"
    done
fi

# Clean up cloned repo
rm -rf "$POWER_PACK_DIR"

echo "power-pack uninstalled successfully"
