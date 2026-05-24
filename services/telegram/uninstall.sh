#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
ENV_FILE="$CONFIG_DIR/.env"

echo "=== Telegram Bridge Uninstall ==="
echo ""

services_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/services"
docker compose -p agentstrator-telegram -f "$services_dir/docker-compose.telegram.yml" --env-file "$ENV_FILE" down 2>/dev/null || true

if [ -f "$ENV_FILE" ]; then
    if grep -q "^TELEGRAM_BOT_TOKEN=" "$ENV_FILE" 2>/dev/null; then
        echo "Removing TELEGRAM_BOT_TOKEN from $ENV_FILE..."
        sed -i '/^TELEGRAM_BOT_TOKEN=/d' "$ENV_FILE"
    fi
    if grep -q "^TELEGRAM_ALLOWED_USERS=" "$ENV_FILE" 2>/dev/null; then
        echo "Removing TELEGRAM_ALLOWED_USERS from $ENV_FILE..."
        sed -i '/^TELEGRAM_ALLOWED_USERS=/d' "$ENV_FILE"
    fi
fi

echo "Telegram bridge uninstalled."
echo ""
echo "Note: Services (registry) remain running."
echo "To stop services: agentstrator services stop"