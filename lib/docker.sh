#!/bin/bash
#
# lib/docker.sh — Docker helper functions
# Depends on: VOLUME_DIR, WORKSPACE, AGENTSTRATOR_INSTALL_DIR (set by caller)
#

# Runtime image name
RUNTIME_IMAGE="agentstrator:runtime"

# Get the runtime image name to use
# Returns: agentstrator:runtime if available, otherwise debian:bookworm-slim
get_runtime_base_image() {
    if check_runtime_image; then
        echo "$RUNTIME_IMAGE"
    else
        echo "debian:bookworm-slim"
    fi
}

# Ensure volume directories and files exist with correct ownership
# This prevents Docker from creating them as root
ensure_volume_structure() {
    mkdir -p "$AGENTSTRATOR_INSTALL_DIR/volume"
    mkdir -p "$AGENTSTRATOR_INSTALL_DIR/.config"
    mkdir -p "$AGENTSTRATOR_INSTALL_DIR/log"
    touch "$AGENTSTRATOR_INSTALL_DIR/registry.json"    
}

# Build the -v flags string for docker run.
# Usage: volumes_str=$(build_volumes_str)
build_volumes_str() {
    local volumes_str=""
    
    # Use runtime image for binaries instead of volume
    # But keep volume mounts for user data (config, logs, registry)
    if [ -d "$AGENTSTRATOR_INSTALL_DIR/volume" ]; then
        volumes_str="${volumes_str} -v ${AGENTSTRATOR_INSTALL_DIR}/volume:/agentstrator"
    fi
    
    # Workspace
    volumes_str="${volumes_str} -v ${WORKSPACE}:/workspace"
    
    # User/group info
    volumes_str="${volumes_str} -v ${AGENTSTRATOR_INSTALL_DIR}/passwd:/etc/passwd"
    volumes_str="${volumes_str} -v ${AGENTSTRATOR_INSTALL_DIR}/group:/etc/group"

    # OpenCode config
    if [ -d "$AGENTSTRATOR_INSTALL_DIR/.config/opencode" ]; then
        volumes_str="${volumes_str} -v ${AGENTSTRATOR_INSTALL_DIR}/.config/opencode:/home/user/.config/opencode"
    fi

    echo "$volumes_str"
}

# Check if runtime image is available
# Returns: 0 if image exists, 1 otherwise
check_runtime_image() {
    docker image inspect "$RUNTIME_IMAGE" >/dev/null 2>&1
}

# Check if the volume directory exists and is non-empty.
# Returns: 0 if volume is valid, 1 otherwise
check_volume() {
    if [ ! -d "$VOLUME_DIR" ] || [ -z "$(ls -A "$VOLUME_DIR" 2>/dev/null)" ]; then
        echo "No agents found in volume. Run agentstrator setup first."
        return 1
    fi
    return 0
}
