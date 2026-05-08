#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
ENV_FILE="$CONFIG_DIR/.env"

echo "Uninstalling Registry service..."

docker stop agentstrator-registry 2>/dev/null || true
docker rm agentstrator-registry 2>/dev/null || true

echo "Registry service uninstalled."