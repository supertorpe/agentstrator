#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    -e "HOME=/agentstrator" \
    -e "OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json" \
    -e "OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode" \
    -e "XDG_CONFIG_HOME=/agentstrator" \
    -e "OPENSPEC_TELEMETRY=0" \
    -w /tmp agentstrator-openspec bash -c "
    export HOME=/agentstrator
    export XDG_CONFIG_HOME=/agentstrator
    mkdir -p /tmp/openspec-init
    cd /tmp/openspec-init
    /usr/local/bin/openspec init --tools opencode
    mkdir -p /agentstrator/.config/opencode/commands
    mv /tmp/openspec-init/.opencode/commands/* /agentstrator/.config/opencode/commands/ 2>/dev/null || true
    mkdir -p /agentstrator/.config/opencode/skills
    mv /tmp/openspec-init/.opencode/skills/* /agentstrator/.config/opencode/skills/ 2>/dev/null || true
    rm -rf /tmp/openspec-init
"

echo "openspec installed successfully"
