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

docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    -e "HOME=/agentstrator" \
    -e OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode \
    -w /agentstrator agentstrator-rtk bash -c "
    /usr/local/bin/rtk init -g --opencode
"

echo "rtk installed successfully"
