#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

mkdir -p "$VOLUME/.mempalace/palace"

if [ ! -f "$VOLUME/.mempalace/identity.txt" ]; then
    echo 'AI Assistant with MemPalace memory system' > "$VOLUME/.mempalace/identity.txt"
fi

if [ ! -f "$VOLUME/.mempalace/wing_config.json" ]; then
    echo '{"default_wing": "wing_general", "wings": {}}' > "$VOLUME/.mempalace/wing_config.json"
fi

add_mcp_to_opencode "$VOLUME" "mempalace" \
    '{"type": "local", "command": ["mempalace-mcp"], "enabled": true}'

echo "mempalace installed successfully"
