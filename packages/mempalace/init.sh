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

if [[ -f $WORKSPACE/mempalace.yaml ]]; then
    echo "mempalace already initialized"
else
    mkdir -p $WORKSPACE/.mempalace
    docker run --rm -it -v "$WORKSPACE:/$PROJECT_NAME" -v "$VOLUME:/agentstrator" -u $(id -u):$(id -g) \
        -e HOME=/agentstrator \
        -e MEMPALACE_PALACE_PATH=/$PROJECT_NAME/.mempalace \
        -w /$PROJECT_NAME \
        agentstrator-mempalace:latest \
        bash -c "
            /usr/local/bin/mempalace init .
            /usr/local/bin/mempalace mine .
        "
fi

