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
    -e "HOME=/agentstrator" \
    -e "OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json" \
    -e "OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode" \
    -w /tmp agentstrator-lean-ctx bash -c "
    export HOME=/agentstrator
    lean-ctx uninstall
"

rm -f "$VOLUME/.config/opencode/plugins/lean-ctx.ts" 2>/dev/null || true

echo "lean-ctx uninstalled successfully"