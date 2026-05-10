#!/bin/bash
# Runs before opencode starts, once per workspace
# Usage: init.sh <workspace_dir> <volume_dir>
# Runs interactively - can prompt for user input

WORKSPACE="$1"
VOLUME="$2"

if [ -z "$WORKSPACE" ] || [ ! -d "$WORKSPACE" ]; then
    exit 0
fi

if [ -f "$WORKSPACE/.codedna" ]; then
    exit 0
fi

PROJECT_NAME=$(basename "$WORKSPACE")

if [ -f "$WORKSPACE/.codedna" ]; then
    exit 0
fi

docker run --rm -it -v "$WORKSPACE:/workspace" -v "$VOLUME:/agentstrator" -u $(id -u):$(id -g) \
    -e HOME=/agentstrator \
    -e OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json \
    -e OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode \
    -w /workspace \
    agentstrator:runtime \
    bash -c "
        export HOME=/agentstrator
        export OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json
        export OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode
        codedna install
        codedna init /workspace --no-llm
    "
