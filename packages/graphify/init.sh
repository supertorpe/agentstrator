#!/bin/bash
# Runs before opencode starts, once per workspace
# Usage: init.sh <workspace_dir> <volume_dir>
# Runs interactively - can prompt for user input

WORKSPACE="$1"
VOLUME="$2"

if [ -z "$WORKSPACE" ] || [ ! -d "$WORKSPACE" ]; then
    exit 0
fi

PROJECT_NAME=$(basename "$WORKSPACE")

docker run --rm -v "$WORKSPACE:/workspace" -v "$VOLUME:/agentstrator" -u $(id -u):$(id -g) \
    -e HOME=/agentstrator \
    -w /workspace \
    agentstrator-graphify:latest \
    bash -c "
        export HOME=/agentstrator
        cd /workspace
        /usr/local/bin/graphify install --platform opencode
    "

if [[ -f $WORKSPACE/graphify-out/graph.json ]]; then
    echo "graph.json already built"
else
    read -p "Press ENTER to continue"
fi

