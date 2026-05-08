#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

mkdir -p "$VOLUME/.config/opencode"
mkdir -p "$VOLUME/.opencode/tools"

# Ensure package.json exists for OpenCode plugin
if [ ! -f "$VOLUME/.opencode/package.json" ]; then
    echo '{"dependencies": {"@opencode-ai/plugin": "1.4.5"}}' > "$VOLUME/.opencode/package.json"
fi

# Install @opencode-ai/plugin for custom tools (will be in runtime image)
if [ ! -d "$VOLUME/.opencode/node_modules" ]; then
    echo "Note: OpenCode plugin will be installed in runtime image"
fi

prompt_copy_config "$HOME/.config/opencode/opencode.json" "$VOLUME/.config/opencode/opencode.json"

# Always ensure opencode.json exists
OPENCODE_CONFIG="$VOLUME/.config/opencode/opencode.json"
if [ ! -f "$OPENCODE_CONFIG" ]; then
    echo "Creating default opencode.json..."
    echo '{"$schema": "https://opencode.ai/config.json"}' > "$OPENCODE_CONFIG"
fi

echo "Core dependencies are now included in the runtime image."
echo "Runtime image will be built automatically."
echo ""
echo "Installed: git, node, npm, opencode-ai"