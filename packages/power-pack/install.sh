#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source commons.sh for helper functions (add_plugin_to_opencode, etc.)
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
elif [ -f "$COMPONENT_DIR/../../commons.sh" ]; then
    source "$COMPONENT_DIR/../../commons.sh"
fi

POWER_PACK_DIR="$VOLUME/power-pack"
COMMANDS_DIR="$VOLUME/.config/opencode/commands"
POWER_PACK_REPO="https://github.com/waybarrios/opencode-power-pack.git"

OC_CONFIG="$VOLUME/.config/opencode/opencode.json"

# Clone the repo onto the volume (needed for command files and file:// plugin URL)
if [ ! -d "$POWER_PACK_DIR/.git" ]; then
    echo "Cloning opencode-power-pack..."
    git clone "$POWER_PACK_REPO" "$POWER_PACK_DIR"
fi

# Ensure opencode.json exists before registering the plugin
# (_patch_opencode in commons.sh skips if the file doesn't exist)
mkdir -p "$(dirname "$OC_CONFIG")"
touch "$OC_CONFIG"

# Register the plugin via file:// URL pointing to the volume clone.
# OpenCode reads the plugin JS from the local clone — no internet at startup needed.
add_plugin_to_opencode "$VOLUME" \
    "opencode-power-pack@git+file:///agentstrator/power-pack" 2>/dev/null || true

# Copy command files (slash commands) into OpenCode commands directory.
# The plugin handles skills auto-discovery; commands need physical files.
mkdir -p "$COMMANDS_DIR"
cp "$POWER_PACK_DIR/commands/"*.md "$COMMANDS_DIR/" 2>/dev/null || true

echo "power-pack installed successfully"
