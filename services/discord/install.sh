#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
ENV_FILE="$CONFIG_DIR/.env"
COMMONS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/commons.sh"
source "$COMMONS"

TTY="$(get_tty 2>/dev/null)"

if [ -n "$TTY" ] && [ -r "$TTY" ] && [ -w "$TTY" ]; then
    echo "=== Discord Bridge Setup ==="
    echo ""

    # Prompt for Discord bot token
    existing_token=$(grep "^DISCORD_BOT_TOKEN=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)
    if [ -n "$existing_token" ]; then
        echo "Current token: ${existing_token:0:10}..."
        while true; do
            echo -n "  Keep this token? [Y/n]: "
            read -r keep < "$TTY"
            keep="${keep:-y}"
            case "$keep" in
                y|yes|Y|"" ) break ;;
                n|no)
                    echo "  To get a new token:"
                    echo "    1. Go to https://discord.com/developers/applications"
                    echo "    2. Create a new application and bot"
                    echo "    3. Copy the token from the Bot section"
                    echo ""
                    echo -n "  Enter Discord Bot Token: "
                    read -r discord_token < "$TTY"
                    existing_token="$discord_token"
                    break
                    ;;
            esac
        done
    else
        echo "To get a bot token:"
        echo "  1. Go to https://discord.com/developers/applications"
        echo "  2. Create a new application and bot"
        echo "  3. Copy the token from the Bot section"
        echo ""
        echo -n "  Enter Discord Bot Token: "
        read -r discord_token < "$TTY"
        existing_token="$discord_token"
    fi

    # Prompt for Discord allowed users
    existing_users=$(grep "^DISCORD_ALLOWED_USERS=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)
    echo ""
    echo "Allowed Discord users (comma-separated usernames or IDs, empty for all):"
    if [ -n "$existing_users" ]; then
        echo "  Current: $existing_users"
    fi
    echo -n "  Allowed users (or press Enter): "
    read -r allowed_users < "$TTY"
    allowed_users="${allowed_users:-$existing_users}"

    env_set "$ENV_FILE" "DISCORD_BOT_TOKEN" "$existing_token"
    env_set "$ENV_FILE" "DISCORD_ALLOWED_USERS" "$allowed_users"
    env_set "$ENV_FILE" "USER_ID" "$(id -u)"
    env_set "$ENV_FILE" "GROUP_ID" "$(id -g)"
    env_set "$ENV_FILE" "CONFIG_DIR" "$CONFIG_DIR"
    env_set "$ENV_FILE" "POLL_INTERVAL" "1"
    env_set "$ENV_FILE" "LOG_RETENTION_DAYS" "30"

    echo ""
    echo "Configuration saved to $ENV_FILE"
else
    echo "=== Discord Bridge Setup ==="
    echo ""
    echo "Warning: No TTY detected. Run this command interactively to configure."
    echo "  DISCORD_BOT_TOKEN and DISCORD_ALLOWED_USERS must be set in $ENV_FILE"
fi

echo ""
mkdir -p "$CONFIG_DIR/log/sessions"

# Ensure registry.json exists and is owned by current user before docker compose
if [ ! -f "$CONFIG_DIR/registry.json" ]; then
    echo '{"agents": []}' > "$CONFIG_DIR/registry.json"
fi

# Build and start services
echo "Building agentstrator-services image..."
services_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/services"

if [ ! -f "$services_dir/Dockerfile.services" ]; then
    echo "ERROR: Dockerfile.services not found at $services_dir"
    exit 1
fi

if docker image inspect agentstrator-services &>/dev/null; then
    echo "agentstrator-services image already exists, skipping build."
else
    docker build -t agentstrator-services "$services_dir" -f "$services_dir/Dockerfile.services"
fi

ensure_network

echo "Starting discord-bridge service..."
docker compose -p agentstrator-discord -f "$services_dir/docker-compose.discord.yml" --env-file "$ENV_FILE" up -d discord-bridge

echo ""
echo "Discord bridge started:"
echo "  - Discord Bridge: (bot should be online)"
echo ""
echo "Discord bridge installed successfully!"
echo ""
echo "To stop services: agentstrator services stop"
echo "To view logs: agentstrator services logs"
