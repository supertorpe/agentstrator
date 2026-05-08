#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

docker run --rm -it -v "$VOLUME:/agentstrator" -u $(id -u):$(id -g) \
    -e HOME=/agentstrator \
    -w /agentstrator \
    agentstrator-agentmemory \
    bash -c "
        export HOME=/agentstrator
        curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
"

add_mcp_to_opencode "$VOLUME" "agentmemory" \
    '{"type": "local", "command": ["npx", "-y", "@agentmemory/mcp"], "enabled": true}'

echo "agentmemory installed successfully"
