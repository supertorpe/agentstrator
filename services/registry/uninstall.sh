#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
ENV_FILE="$CONFIG_DIR/.env"

echo "Uninstalling Registry service..."

services_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/services"
docker compose -p agentstrator-registry -f "$services_dir/docker-compose.registry.yml" --env-file "$ENV_FILE" down 2>/dev/null || true

echo "Registry service uninstalled."