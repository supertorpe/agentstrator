#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    agentstrator-context-mode bash -c "
    cp -r /usr/local/lib/node_modules/context-mode/configs/opencode/AGENTS.md /agentstrator/.config/opencode/context-mode.md
"

add_instructions_to_opencode "$VOLUME" "/agentstrator/.config/opencode/context-mode.md" 2>/dev/null || true

add_mcp_to_opencode "$VOLUME" "context-mode" \
    '{"type": "local", "command": ["context-mode"], "enabled": true}'

add_plugin_to_opencode "$VOLUME" "context-mode"

echo "context-mode installed successfully"
