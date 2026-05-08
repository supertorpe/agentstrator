#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

mkdir -p "$VOLUME/.config/gentle-ai"
mkdir -p "$VOLUME/.config/opencode"

docker run --rm -it \
    -v "$VOLUME:/agentstrator" \
    -u $(id -u):$(id -g) \
    -e HOME=/agentstrator \
    -e OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json \
    -e OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode \
    --entrypoint bash agentstrator-gentle-ai -c "
        export HOME=/agentstrator
        export OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json
        export OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode
        /usr/local/bin/gentle-ai install
    "

echo "gentle-ai installed successfully"