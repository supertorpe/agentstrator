#!/bin/bash
# Runs before opencode starts, once per workspace
# Usage: init.sh <workspace_dir> <volume_dir>
# Runs interactively - can prompt for user input

WORKSPACE="$1"
VOLUME="$2"

if [ -z "$WORKSPACE" ] || [ ! -d "$WORKSPACE" ]; then
    exit 0
fi

if [ -f "$WORKSPACE/bmalph/config.json" ]; then
    exit 0
fi

PROJECT_NAME=$(basename "$WORKSPACE")

docker run --rm -it -v "$WORKSPACE:/workspace" -v "$VOLUME:/agentstrator" -u $(id -u):$(id -g) \
    -e HOME=/agentstrator \
    agentstrator:runtime \
    bmalph init --platform opencode --name "$PROJECT_NAME" --description "Agentstrator project" --project-dir /workspace