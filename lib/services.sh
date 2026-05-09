#!/bin/bash
#
# lib/services.sh — Services management functions
# Depends on: AGENTSTRATOR_INSTALL_DIR, ENV_FILE (set by caller)
#

# ============================================================
# Helper: Map service name to config.json key
# ============================================================

service_to_config_key() {
    case "$1" in
        registry) echo "Registry" ;;
        telegram-bridge) echo "telegram" ;;
        discord-bridge) echo "discord" ;;
        *) echo "$1" ;;
    esac
}

# ============================================================
# Check if a service is installed per config.json
# ============================================================

is_service_installed() {
    local service="$1"
    local config_key
    config_key=$(service_to_config_key "$service")
    local config_file="$AGENTSTRATOR_INSTALL_DIR/config.json"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Check if installed: true in config.json
    local installed
    installed=$(jq -r ".${config_key}.installed // false" "$config_file" 2>/dev/null || echo "false")
    [ "$installed" = "true" ]
}

# ============================================================
# Helper: Get compose file path for a service
# ============================================================

get_compose_file() {
    local service="$1"
    case "$service" in
        registry|Registry) echo "$AGENTSTRATOR_INSTALL_DIR/services/docker-compose.registry.yml" ;;
        telegram|telegram-bridge) echo "$AGENTSTRATOR_INSTALL_DIR/services/docker-compose.telegram.yml" ;;
        discord|discord-bridge) echo "$AGENTSTRATOR_INSTALL_DIR/services/docker-compose.discord.yml" ;;
        *) echo "" ;;
    esac
}

# ============================================================
# Start services
# ============================================================

services_start() {
    local service="$1"

    if ! docker network inspect agentstrator-net &>/dev/null; then
        echo "Creating agentstrator-net network..."
        docker network create agentstrator-net
    fi

    local user_id=$(id -u)
    local group_id=$(id -g)

    mkdir -p "$AGENTSTRATOR_INSTALL_DIR/log/sessions"

    if [ ! -f "$AGENTSTRATOR_INSTALL_DIR/registry.json" ]; then
        echo '{"agents": []}' > "$AGENTSTRATOR_INSTALL_DIR/registry.json"
    fi

    if [ -n "$service" ]; then
        if ! is_service_installed "$service"; then
            echo "ERROR: Service $service not installed. Run agentstrator setup to install."
            exit 1
        fi

        local compose_file
        compose_file=$(get_compose_file "$service")
        if [ -z "$compose_file" ] || [ ! -f "$compose_file" ]; then
            echo "ERROR: Service $service compose file not found."
            exit 1
        fi

        echo "Starting $service..."
        local project_name
        case "$service" in
            registry|Registry) project_name="agentstrator-registry" ;;
            telegram|telegram-bridge) project_name="agentstrator-telegram" ;;
            discord|discord-bridge) project_name="agentstrator-discord" ;;
        esac
        docker compose -p "$project_name" -f "$compose_file" --env-file "$ENV_FILE" up -d
        return
    fi

    echo "Starting installed services..."

    # Read config.json and start any service with installed: true
    local config_file="$AGENTSTRATOR_INSTALL_DIR/config.json"
    if [ -f "$config_file" ]; then
        local services
        services=$(jq -r 'to_entries[] | select(.value.type == "service" and .value.installed == true) | .key' "$config_file" 2>/dev/null || true)

        for config_key in $services; do
            case "$config_key" in
                Registry)
                    docker compose -p agentstrator-registry -f "$AGENTSTRATOR_INSTALL_DIR/services/docker-compose.registry.yml" --env-file "$ENV_FILE" up -d registry
                    echo "Registry: http://localhost:8090"
                    ;;
                telegram)
                    docker compose -p agentstrator-telegram -f "$AGENTSTRATOR_INSTALL_DIR/services/docker-compose.telegram.yml" --env-file "$ENV_FILE" up -d telegram-bridge
                    echo "Telegram Bridge: online"
                    ;;
                discord)
                    docker compose -p agentstrator-discord -f "$AGENTSTRATOR_INSTALL_DIR/services/docker-compose.discord.yml" --env-file "$ENV_FILE" up -d discord-bridge
                    echo "Discord Bridge: online"
                    ;;
            esac
        done
    fi

    if [ -z "$services" ]; then
        echo "No services installed. Run agentstrator setup to install services."
    fi
}

# ============================================================
# Stop services
# ============================================================

services_stop() {
    local service="$1"

    if [ -n "$service" ]; then
        if ! is_service_installed "$service"; then
            echo "ERROR: Service $service not installed."
            exit 1
        fi

        local compose_file
        compose_file=$(get_compose_file "$service")
        if [ -z "$compose_file" ] || [ ! -f "$compose_file" ]; then
            echo "ERROR: Service $service compose file not found."
            exit 1
        fi

        local project_name
        case "$service" in
            registry|Registry) project_name="agentstrator-registry" ;;
            telegram|telegram-bridge) project_name="agentstrator-telegram" ;;
            discord|discord-bridge) project_name="agentstrator-discord" ;;
        esac

        docker compose -p "$project_name" -f "$compose_file" --env-file "$ENV_FILE" down 2>/dev/null || true
        echo "$service stopped."
        return
    fi

    echo "Stopping installed services..."

    local config_file="$AGENTSTRATOR_INSTALL_DIR/config.json"
    if [ -f "$config_file" ]; then
        local services
        services=$(jq -r 'to_entries[] | select(.value.type == "service" and .value.installed == true) | .key' "$config_file" 2>/dev/null || true)

        for config_key in $services; do
            local compose_file
            compose_file=$(get_compose_file "$config_key")
            if [ -f "$compose_file" ]; then
                local project_name
                case "$config_key" in
                    Registry) project_name="agentstrator-registry" ;;
                    telegram) project_name="agentstrator-telegram" ;;
                    discord) project_name="agentstrator-discord" ;;
                esac

                docker compose -p "$project_name" -f "$compose_file" --env-file "$ENV_FILE" down 2>/dev/null || true
                echo "$config_key stopped."
            fi
        done
    fi

    echo "All services stopped."
}

# ============================================================
# Restart a service
# ============================================================

services_restart() {
    local service="$1"
    services_stop "$service"
    services_start "$service"
}

# ============================================================
# Show logs for a service
# ============================================================

services_logs() {
    local service="$1"

    if [ -z "$service" ]; then
        echo "Usage: agentstrator services logs <service>"
        echo "Services: registry, telegram-bridge, discord-bridge"
        exit 1
    fi

    local compose_file
    compose_file=$(get_compose_file "$service")
    if [ -z "$compose_file" ] || [ ! -f "$compose_file" ]; then
        echo "ERROR: Service $service not installed."
        exit 1
    fi

    docker compose -f "$compose_file" --env-file "$ENV_FILE" logs -f
}

# ============================================================
# Show status of all services
# ============================================================

services_status() {
    local config_file="$AGENTSTRATOR_INSTALL_DIR/config.json"

    if [ ! -f "$config_file" ]; then
        echo "No services installed. Run agentstrator setup to install."
        return
    fi

    local installed_services
    installed_services=$(jq -r 'to_entries[] | select(.value.type == "service" and .value.installed == true) | .key' "$config_file" 2>/dev/null || true)

    if [ -z "$installed_services" ]; then
        echo "No services installed. Run agentstrator setup to install."
        return
    fi

    for config_key in $installed_services; do
        local project_name compose_file
        case "$config_key" in
            Registry) project_name="agentstrator-registry" ;;
            telegram) project_name="agentstrator-telegram" ;;
            discord) project_name="agentstrator-discord" ;;
        esac
        compose_file=$(get_compose_file "$config_key")
        [ -f "$compose_file" ] || continue

        echo "--- $config_key ---"
        docker compose -p "$project_name" -f "$compose_file" --env-file "$ENV_FILE" ps 2>/dev/null || echo "not running"
    done
}

# ============================================================
# Build the agentstrator-services Docker image
# ============================================================

services_build() {
    local services_dir="$AGENTSTRATOR_INSTALL_DIR/services"

    if [ ! -f "$services_dir/Dockerfile.services" ]; then
        echo "ERROR: Dockerfile.services not found."
        exit 1
    fi

    echo "Building agentstrator-services image..."
    docker build -t agentstrator-services "$services_dir" -f "$services_dir/Dockerfile.services"
    echo "Services image built."
}

# ============================================================
# Show help for services command
# ============================================================

services_help() {
    echo "Usage: agentstrator services <command> [service]"
    echo ""
    echo "Commands:"
    echo "  start [service]    Start specific service (registry/telegram-bridge/discord-bridge)"
    echo "  stop [service]     Stop specific service"
    echo "  restart [service]  Restart specific service"
    echo "  logs <service>     Show logs for service"
    echo "  status             Show all service status"
    echo "  build              Build agentstrator-services image"
    echo "  help               Show this help"
    echo ""
    echo "Services:"
    echo "  registry, telegram-bridge, discord-bridge"
    echo ""
    echo "Environment:"
    echo "  Edit $ENV_FILE to configure TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USERS,"
    echo "  DISCORD_BOT_TOKEN, DISCORD_ALLOWED_USERS and other settings"
}

# ============================================================
# Dispatch services subcommands
# ============================================================

run_services() {
    local args=("$@")
    local cmd="${args[0]:-help}"

    case "$cmd" in
        start)   services_start "${args[1]:-}" ;;
        stop)    services_stop "${args[1]:-}" ;;
        restart) services_restart "${args[1]:-}" ;;
        logs)    services_logs "${args[1]:-}" ;;
        status)  services_status ;;
        build)   services_build ;;
        help|--help|-h) services_help ;;
        *)
            echo "Unknown command: $cmd"
            echo ""
            services_help
            exit 1
            ;;
    esac
}
