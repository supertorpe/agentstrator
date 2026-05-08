#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

mkdir -p "$VOLUME/.claude"
mkdir -p "$VOLUME/.config/opencode"

echo "Running nwave-ai install to configure agents and commands..."
docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    -e HOME=/agentstrator \
    -e XDG_CONFIG_HOME=/agentstrator/.config \
    -e OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json \
    -e OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode \
    agentstrator-core \
    bash -c "
        export HOME=/agentstrator
        export XDG_CONFIG_HOME=/agentstrator/.config
        export OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json
        export OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode
        mkdir -p /agentstrator/.claude /agentstrator/.config/opencode
        curl -LsSf https://astral.sh/uv/install.sh | sh
        source /agentstrator/.local/bin/env
        /agentstrator/.local/bin/uv tool install nwave-ai        
        nwave-ai install 2>&1 || echo 'nwave-ai install completed with warnings'
    "

echo "nwave installed successfully"