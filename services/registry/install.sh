#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
ENV_FILE="$CONFIG_DIR/.env"
COMMONS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/commons.sh"
source "$COMMONS"

echo "Installing Registry service..."

services_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/services"

if ! docker image inspect agentstrator-services &>/dev/null; then
    echo "Building agentstrator-services image..."
    docker build -t agentstrator-services "$services_dir" -f "$services_dir/Dockerfile.services"
fi

ensure_network

if [ ! -f "$CONFIG_DIR/registry.json" ]; then
    echo '{"agents": []}' > "$CONFIG_DIR/registry.json"
fi

if docker ps --format '{{.Names}}' | grep -q "^agentstrator-registry$"; then
    echo "Registry already running."
    exit 0
fi

echo "Starting registry service..."
docker compose -p agentstrator-registry -f "$services_dir/docker-compose.registry.yml" --env-file "$ENV_FILE" down --remove-orphans 2>/dev/null || true
docker compose -p agentstrator-registry -f "$services_dir/docker-compose.registry.yml" --env-file "$ENV_FILE" up -d registry

echo "Registry service installed at http://localhost:8090"