#!/bin/bash
#
# lib/cli.sh — client and server mode functions
# Depends on: VOLUME_DIR, CONFIG_FILE, ENV_FILE, AGENTSTRATOR_INSTALL_DIR
#             (set by agentstrator before sourcing), commons.sh, lib/docker.sh, lib/registry.sh, lib/utils.sh
#

# ============================================================
# Global state (set by agentstrator before sourcing)
# ============================================================

MODE="cli"
EXPLICIT_MODE=""
WORKSPACE="$(pwd)"
CUSTOM_REGISTRY_URL=""
REGISTRY_URL="${REGISTRY_URL:-http://localhost:8090}"
SERVER_MODE=false
AGENT_NAME=""
AGENT_URL=""
ATTACH_CONTAINER=""
DEV_CONTAINER=""
DEV_MODE=""
DEV_WORKDIR=""

# ============================================================
# Help
# ============================================================

show_cli_help() {
    echo "Usage: agentstrator [COMMAND] [OPTIONS]..."
    echo ""
    echo "Commands:"
    echo "  setup              Run interactive installer / uninstall"
    echo "  list               List all available packages"
    echo "  info <pkg>         Show package details"
    echo "  install <pkg>      Install a package"
    echo "  remove <pkg>       Uninstall a package"
    echo "  upgrade            Upgrade agentstrator (check GitHub, download, rebuild)"
    echo "  status             Check if agentstrator upgrade is available"
    echo "  rebuild            Reinstall all packages (force Docker rebuild)"
    echo "  services <cmd>     Manage services (start/stop/restart/logs/status/build)"
    echo ""
    echo "Options:"
    echo "  --cli              Run in client mode"
    echo "  --srv              Run in server mode (register with registry)"
    echo "  --shell            Start an interactive shell"
    echo "  --dev, -d [CONTAINER] --mode cli|srv [--workdir PATH]"
    echo "                     Run in dev container mode (container optional if using menu)"
    echo "  --registry, -r URL Set registry URL"
    echo "  --name NAME        Set agent name for registry"
    echo "  --help, -h         Show this help"
    echo ""
    echo "Examples:"
    echo "  agentstrator                                   # Interactive launcher"
    echo "  agentstrator setup                             # Interactive installer"
    echo "  agentstrator list                              # List packages"
    echo "  agentstrator install rtk                       # Install RTK package"
    echo "  agentstrator upgrade                           # Upgrade agentstrator itself"
    echo "  agentstrator status                            # Check if upgrade is available"
    echo "  agentstrator --srv -r http://localhost:8090    # Server mode with custom registry"
    echo "  agentstrator -d mycontainer --mode srv         # Dev container server mode"
}

# ============================================================
# Argument parsing
# ============================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cli)
                MODE="cli"
                EXPLICIT_MODE=true
                shift
                ;;
            --srv)
                MODE="srv"
                SERVER_MODE=true
                EXPLICIT_MODE=true
                shift
                ;;
            --register-container|-C)
                if [[ -n "${2:-}" ]] && [[ ! "${2:-}" =~ ^-- ]]; then
                    ATTACH_CONTAINER="$2"
                    shift 2
                else
                    ATTACH_CONTAINER="select"
                    shift
                fi
                EXPLICIT_MODE=true
                ;;
            --registry|-r)
                CUSTOM_REGISTRY_URL="$2"
                shift 2
                ;;
            --name)
                AGENT_NAME="$2"
                shift 2
                ;;
            --help|-h)
                show_cli_help
                exit 0
                ;;
            --shell)
                MODE="shell"
                EXPLICIT_MODE=true
                shift
                ;;
            --dev|-d)
                MODE="dev"
                EXPLICIT_MODE=true
                if [[ -n "${2:-}" ]] && [[ ! "${2:-}" =~ ^-- ]]; then
                    DEV_CONTAINER="$2"
                    shift 2
                fi
                ;;
            --mode)
                if [[ -n "${2:-}" ]]; then
                    case "$2" in
                        cli|srv)
                            DEV_MODE="$2"
                            shift 2
                            ;;
                        *)
                            echo "ERROR: Invalid --mode '$2'. Use 'cli' or 'srv'"
                            exit 1
                            ;;
                    esac
                else
                    echo "ERROR: --mode requires a value (cli or srv)"
                    exit 1
                fi
                ;;
            --workdir)
                DEV_WORKDIR="$2"
                shift 2
                ;;
        esac
    done
}

# ============================================================
# Core / package path helpers
# ============================================================

get_core_path() {
    local core_dir="$AGENTSTRATOR_INSTALL_DIR/core"
    local result=""

    if [ -d "$core_dir" ]; then
        if [ -f "$core_dir/metadata" ]; then
            local p
            p=$(grep "^PATH=" "$core_dir/metadata" 2>/dev/null | cut -d'=' -f2-)
            if [ -n "$p" ]; then
                result="$p"
            fi
        else
            for component in "$core_dir"/*/; do
                [ -d "$component" ] || continue
                local metadata_file="$component/metadata"
                if [ -f "$metadata_file" ]; then
                    local p
                    p=$(grep "^PATH=" "$metadata_file" 2>/dev/null | cut -d'=' -f2-)
                    if [ -n "$p" ]; then
                        if [ -n "$result" ]; then
                            result="$result:$p"
                        else
                            result="$p"
                        fi
                    fi
                fi
            done
        fi
    fi

    echo "$result"
}

build_package_paths() {
    local paths=""
    local seen_paths=":"

    add_path() {
        local path="$1"
        if [ -n "$path" ]; then
            if [[ "$seen_paths" != *":${path}:"* ]]; then
                if [ -n "$paths" ]; then
                    paths="$paths:${path}"
                else
                    paths="${path}"
                fi
                seen_paths="${seen_paths}${path}:"
            fi
        fi
    }

    if [ -f "$CONFIG_FILE" ]; then
        local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"
        if [ -d "$packages_dir" ]; then
            for tool_dir in "$packages_dir"/*/; do
                [ -d "$tool_dir" ] || continue
                local name
                name=$(grep "^NAME=" "$tool_dir/metadata" 2>/dev/null | cut -d'=' -f2-)
                [ -z "$name" ] && continue
                local installed
                installed=$(jq -r ".\"$name\".installed // false" "$CONFIG_FILE" 2>/dev/null)
                if [ "$installed" = "true" ]; then
                    local tool_path
                    tool_path=$(grep "^PATH=" "$tool_dir/metadata" | cut -d'=' -f2-)
                    IFS=':' read -ra path_parts <<< "$tool_path"
                    for part in "${path_parts[@]}"; do
                        add_path "$part"
                    done
                fi
            done
        fi
    fi

    local core_paths
    core_paths=$(get_core_path)
    IFS=':' read -ra core_path_parts <<< "$core_paths"
    for part in "${core_path_parts[@]}"; do
        add_path "$part"
    done

    echo "$paths"
}

get_package_commands() {
    local cmds=""
    if [ -f "$CONFIG_FILE" ]; then
        local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"
        if [ -d "$packages_dir" ]; then
            for dir in "$packages_dir"/*/; do
                [ -d "$dir" ] || continue
                local pkg
                pkg=$(grep "^NAME=" "$dir/metadata" 2>/dev/null | cut -d'=' -f2-)
                [ -z "$pkg" ] && continue
                local installed
                installed=$(jq -r ".\"$pkg\".installed // false" "$CONFIG_FILE" 2>/dev/null)
                if [ "$installed" = "true" ]; then
                    local cmd
                    cmd=$(grep "^COMMANDS=" "$dir/metadata" 2>/dev/null | cut -d'=' -f2-)
                    [ -n "$cmd" ] && cmds="$cmds,$cmd"
                fi
            done
        fi
    fi
    echo "${cmds#,}"
}

# ============================================================
# Service checks
# ============================================================

check_services() {
    registry_installed
}

start_services_internal() {
    local config_file="$AGENTSTRATOR_INSTALL_DIR/config.json"
    if [ -f "$config_file" ] && jq -e '.Registry.installed == true' "$config_file" >/dev/null 2>&1; then
        docker compose -f "$AGENTSTRATOR_INSTALL_DIR/services/docker-compose.registry.yml" --env-file "$ENV_FILE" up -d registry
    else
        echo "Warning: registry not installed. Run agentstrator setup to install."
    fi
    sleep 2
}

# ============================================================
# Container selection / attachment
# ============================================================

get_running_containers() {
    docker ps --format '{{.Names}}' 2>/dev/null | while read -r name; do
        [[ "$name" =~ ^agentstrator- ]] && continue
        local hostname
        hostname=$(docker inspect --format '{{.Config.Hostname}}' "$name" 2>/dev/null)
        [[ -z "$hostname" ]] && hostname="$name"
        local networks
        networks=$(docker inspect --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' "$name" 2>/dev/null)
        local image
        image=$(docker inspect --format '{{.Config.Image}}' "$name" 2>/dev/null)
        echo "${name}|${hostname}|${networks}|${image}"
    done
}

select_container() {
    local containers=()
    local names=()
    local hostnames=()
    local images=()

    while IFS='|' read -r name hostname networks image; do
        [[ -z "$name" ]] && continue
        containers+=("$name")
        images+=("$image")
        names+=("$name")
        hostnames+=("$hostname")
    done < <(get_running_containers)

    if [[ ${#containers[@]} -eq 0 ]]; then
        echo "No running containers found."
        return 1
    fi

    if ! command -v whiptail &>/dev/null; then
        echo "Error: whiptail not found. Please install it."
        return 1
    fi

    if ! [[ -t 0 ]] && ! [[ -t 1 ]]; then
        echo "Error: No terminal attached."
        return 1
    fi

    local whiptail_args=("--title" "Select Container" "--menu" "Choose a container to join:" 20 80 10)

    for i in "${!containers[@]}"; do
        whiptail_args+=("$i" "${containers[$i]}")
    done

    local selected
    selected=$(whiptail "${whiptail_args[@]}" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$selected" ]]; then
        return 1
    fi

    ATTACH_CONTAINER="${names[$selected]}"
    return 0
}

show_mode_menu() {
    if ! command -v whiptail &>/dev/null; then
        echo "Error: whiptail not found. Please install it."
        exit 1
    fi

    if ! [[ -t 0 ]] && ! [[ -t 1 ]]; then
        echo "Error: No terminal attached."
        exit 1
    fi

    local choice
    choice=$(whiptail --title "Agentstrator" --menu "Select mode:" 20 80 10 \
        "1" "Client Mode - Run opencode interactively" \
        "2" "Server Mode - Run opencode server" \
        "3" "Shell - Start an interactive shell" \
        "4" "Dev Container Mode - Execute commands in dev container" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$choice" ]]; then
        exit 1
    fi

    case "$choice" in
        1)
            MODE="cli"
            EXPLICIT_MODE=true
            ;;
        2)
            MODE="srv"
            EXPLICIT_MODE=true
            ;;
        3)
            MODE="shell"
            EXPLICIT_MODE=true
            ;;
        4)
            run_dev_container_mode
            exit $?
            ;;
        *)
            exit 1
            ;;
    esac
}

# ============================================================
# Registry URL
# ============================================================

get_registry_url() {
    local registry_url="${CUSTOM_REGISTRY_URL}"

    if [[ -z "$registry_url" ]] && [ -f "$ENV_FILE" ]; then
        registry_url=$(grep "^REGISTRY_URL=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
    fi

    if [[ -z "$registry_url" ]]; then
        if check_services; then
            registry_url="http://localhost:8090"
        else
            if [ -f "$AGENTSTRATOR_INSTALL_DIR/registry.json" ]; then
                registry_url="file://$AGENTSTRATOR_INSTALL_DIR/registry.json"
            fi
        fi
    fi

    if [[ -z "$registry_url" ]] || [[ "$registry_url" == "http://localhost:8090" ]]; then
        if command -v whiptail &>/dev/null && [[ -t 0 ]] && [[ -t 1 ]]; then
            local input
            input=$(whiptail --title "Registry URL" --inputbox "Enter registry URL:" 10 50 "http://localhost:8090" 3>&1 1>&2 2>&3)

            if [[ $? -ne 0 ]] || [[ -z "$input" ]]; then
                registry_url="file://$AGENTSTRATOR_INSTALL_DIR/registry.json"
            else
                registry_url="$input"
            fi
        else
            registry_url="file://$AGENTSTRATOR_INSTALL_DIR/registry.json"
        fi
    fi

    echo "$registry_url"
}

# ============================================================
# Container attachment
# ============================================================

attach_container() {
    local container_name="$1"
    local attach_mode="$2"
    local was_connected=false

    local registry_url
    registry_url=$(get_registry_url)

    local container_state
    container_state=$(docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Container '$container_name' not found"
        return 1
    fi
    if [[ "$container_state" != "running" ]]; then
        echo "ERROR: Container '$container_name' is not running (state: $container_state)"
        return 1
    fi

    local on_network
    on_network=$(docker inspect --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' "$container_name" 2>/dev/null)
    if [[ ! "$on_network" =~ agentstrator-net ]]; then
        echo "Container '$container_name' not on agentstrator-net. Connecting..."
        docker network connect agentstrator-net "$container_name" 2>/dev/null || true
        was_connected=true
    fi

    trap "if $was_connected; then docker network disconnect agentstrator-net '$container_name' 2>/dev/null || true; fi" EXIT

    local has_opencode=false
    if docker exec "$container_name" test -f /agentstrator/opencode 2>/dev/null; then
        has_opencode=true
    elif docker exec "$container_name" which opencode 2>/dev/null | grep -q .; then
        has_opencode=true
    fi

    if [[ "$has_opencode" == "false" ]]; then
        echo "ERROR: opencode not found in container '$container_name'"
        return 1
    fi

    local container_workdir
    container_workdir=$(docker inspect --format '{{.Config.WorkingDir}}' "$container_name" 2>/dev/null)
    [[ -z "$container_workdir" ]] && container_workdir="/"

    if [[ -z "$attach_mode" ]]; then
        if ! command -v whiptail &>/dev/null; then
            echo "Error: whiptail not found. Please install it."
            return 1
        fi

        if ! [[ -t 0 ]] && ! [[ -t 1 ]]; then
            echo "Error: No terminal attached."
            return 1
        fi

        local mode_choice
        mode_choice=$(whiptail --title "Select Mode" --menu "Container: $container_name" 15 50 3 \
            "1" "Client - Run opencode interactively (no registry)" \
            "2" "Server - Run opencode server (register with registry)" 3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]] || [[ -z "$mode_choice" ]]; then
            return 1
        fi

        if [[ "$mode_choice" == "2" ]]; then
            attach_mode="srv"
        else
            attach_mode="cli"
        fi
    fi

    if [[ "$attach_mode" == "cli" ]]; then
        echo ""
        echo "Starting opencode in client mode inside container '$container_name'..."
        docker exec -it "$container_name" bash -c "
            export HOME=\${HOME:-/agentstrator}
            export PATH=/agentstrator:/agentstrator/.npm-global/bin:\$PATH
            cd '$container_workdir'
            opencode
        "
        return $?
    fi

    local container_hostname
    container_hostname=$(docker inspect --format '{{.Config.Hostname}}' "$container_name" 2>/dev/null)
    [[ -z "$container_hostname" ]] && container_hostname="$container_name"

    local agent_url
    agent_url=$(docker inspect --format '{{range .Config.Env}}{{if hasPrefix . "AGENT_URL="}}{{trimPrefix . "AGENT_URL="}}{{end}}{{end}}' "$container_name" 2>/dev/null)
    [[ -z "$agent_url" ]] && agent_url="http://${container_hostname}:8080"

    local agent_name
    agent_name=$(docker inspect --format '{{range .Config.Env}}{{if hasPrefix . "AGENT_NAME="}}{{trimPrefix . "AGENT_NAME="}}{{end}}{{end}}' "$container_name" 2>/dev/null)
    [[ -z "$agent_name" ]] && agent_name="$container_name"

    echo ""
    echo "Registering container '$container_name' with registry..."
    echo "  Agent name:  $agent_name"
    echo "  Agent URL:   $agent_url"
    echo "  Registry:    $registry_url"
    echo ""

    if ! register_with_registry "$agent_name" "$agent_url" "$registry_url"; then
        echo "ERROR: Failed to register. Exiting."
        return 1
    fi

    echo ""
    echo "Starting opencode server inside container '$container_name'..."

    docker exec -d "$container_name" \
        bash -c "
            export HOME=\${HOME:-/agentstrator}
            export PATH=/agentstrator:/agentstrator/.npm-global/bin:\$PATH
            export AGENT_URL='http://${container_hostname}:8080'
            export AGENT_NAME='$agent_name'
            cd '$container_workdir'
            opencode serve --hostname 0.0.0.0 --port 8080
        "

    trap - EXIT
}

# ============================================================
# Package metadata helpers
# ============================================================

get_package_ports() {
    local ports=""
    local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"

    if [ -f "$CONFIG_FILE" ] && [ -d "$packages_dir" ]; then
        for tool_dir in "$packages_dir"/*/; do
            [ -d "$tool_dir" ] || continue
            local tool_name
            tool_name=$(grep "^NAME=" "$tool_dir/metadata" 2>/dev/null | cut -d'=' -f2-)
            [ -z "$tool_name" ] && continue

            local installed
            installed=$(jq -r ".\"$tool_name\".installed // false" "$CONFIG_FILE" 2>/dev/null)
            if [ "$installed" = "true" ] && [ -f "$tool_dir/metadata" ]; then
                local port
                port=$(grep "^PORT=" "$tool_dir/metadata" 2>/dev/null | cut -d'=' -f2-)
                if [ -n "$port" ]; then
                    local host_port
                    host_port=$(find_free_port "$port")
                    ports="${ports} -p ${host_port}:${port}"
                fi
            fi
        done
    fi

    echo "$ports"
}

get_package_run_cmds() {
    local cmds=""
    local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"

    if [ -f "$CONFIG_FILE" ] && [ -d "$packages_dir" ]; then
        for tool_dir in "$packages_dir"/*/; do
            [ -d "$tool_dir" ] || continue
            local tool_name
            tool_name=$(grep "^NAME=" "$tool_dir/metadata" 2>/dev/null | cut -d'=' -f2-)
            [ -z "$tool_name" ] && continue

            local installed
            installed=$(jq -r ".\"$tool_name\".installed // false" "$CONFIG_FILE" 2>/dev/null)
            if [ "$installed" = "true" ] && [ -f "$tool_dir/metadata" ]; then
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    local cmd="${line#RUN=}"
                    [ "$line" = "$cmd" ] && continue
                    if [ -n "$cmd" ]; then
                        [ -n "$cmds" ] && cmds="${cmds}; "
                        cmds="${cmds}${cmd}"
                    fi
                done < <(grep "^RUN=" "$tool_dir/metadata" 2>/dev/null)
            fi
        done
    fi

    echo "$cmds"
}

get_package_env_vars() {
    local workdir="${1:-/workspace}"
    local env_vars=""
    local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"

    if [ -d "$packages_dir" ]; then
        for tool_dir in "$packages_dir"/*/; do
            [ -d "$tool_dir" ] || continue
            local tool_name
            tool_name=$(grep "^NAME=" "$tool_dir/metadata" 2>/dev/null | cut -d'=' -f2-)
            [ -z "$tool_name" ] && continue

            local installed=false
            if [ -f "$CONFIG_FILE" ]; then
                installed=$(jq -r ".\"$tool_name\".installed // false" "$CONFIG_FILE" 2>/dev/null)
            fi
            if [ "$installed" = "true" ] && [ -f "$tool_dir/metadata" ]; then
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    local env_pair="${line#ENV=}"
                    [ "$line" = "$env_pair" ] && continue
                    [ -n "$env_pair" ] && {
                        # Replace {WORKDIR} with actual workdir
                        env_pair="${env_pair//\{WORKDIR\}/$workdir}"
                        env_vars="${env_vars} -e ${env_pair}"
                    }
                done < <(grep "^ENV=" "$tool_dir/metadata" 2>/dev/null)
            fi
        done
    fi

    echo "$env_vars"
}

build_env_vars() {
    local additional_path="$1"
    local extra_envs="$2"
    local workdir="${3:-/workspace}"
    local config_path="${4:-/agentstrator/.config/opencode/opencode.json}"
    local tool_env_vars
    tool_env_vars=$(get_package_env_vars "$workdir")

    local result="-e HOME=/agentstrator -e USER=user -e PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/agentstrator/.local/bin${additional_path} -e OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode -e OPENCODE_CONFIG=${config_path} ${tool_env_vars} ${extra_envs}"
    echo "$result"
}

select_working_dir() {
    local container="$1"
    local default_dir
    default_dir=$(docker inspect -f '{{.Config.WorkingDir}}' "$container" 2>/dev/null)
    [[ -z "$default_dir" ]] && default_dir="/"

    local choice
    choice=$(whiptail --title "Working Directory" --menu "Container: $container" 16 50 4 \
        "1" "Default ($default_dir)" \
        "2" "Root (/)" \
        "3" "Custom path" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$choice" ]]; then
        return 1
    fi

    case "$choice" in
        1) echo "__DEFAULT__" ;;
        2) echo "/" ;;
        3)
            local input
            input=$(whiptail --title "Custom Path" --inputbox "Enter working directory:" 10 50 "" 3>&1 1>&2 2>&3)

            if [[ $? -ne 0 ]] || [[ -z "$input" ]]; then
                return 1
            fi

            echo "$input"
            ;;
        *) return 1 ;;
    esac
}

# ============================================================
# Package initialization
# ============================================================

run_package_inits() {
    local workspace="$1"
    local volume="$2"

    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi

    local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"
    for tool_dir in "$packages_dir"/*/; do
        [ -d "$tool_dir" ] || continue
        local tool_name
        tool_name=$(grep "^NAME=" "$tool_dir/metadata" 2>/dev/null | cut -d'=' -f2-)
        [ -z "$tool_name" ] && continue

        local installed
        installed=$(jq -r ".\"$tool_name\".installed // false" "$CONFIG_FILE" 2>/dev/null)
        if [ "$installed" = "true" ] && [ -f "$tool_dir/init.sh" ]; then
            echo "Running $tool_name initialization..."
            bash "$tool_dir/init.sh" "$workspace" "$volume"
        fi
    done
}

# ============================================================
# Mode runners
# ============================================================

build_worker_name() {
    base_name="$(basename "$WORKSPACE")"
    sanitized_base="$(sanitize_name "$base_name")"
    hash="$(hash_base64 "$WORKSPACE")"
    short_hash="${hash:0:8}"

    echo "${sanitized_base}-${short_hash}"
}

run_cli_mode() {
    local agent="${1:-opencode}"

    local tool_path
    tool_path=$(build_package_paths)

    echo "Starting $agent in client mode at $WORKSPACE..."

    run_package_inits "$WORKSPACE" "$VOLUME_DIR"

    ensure_network

    ensure_volume_structure

    local volumes_str
    volumes_str=$(build_volumes_str)

    local additional_path
    additional_path=$(build_path_str "$tool_path")

    local env_vars
    env_vars=$(build_env_vars "$additional_path" "" "/workspace")

    local tool_ports
    tool_ports=$(get_package_ports)

    local interactive="-it"
    if [[ -t 0 ]]; then
        interactive="-it"
    else
        interactive="-t"
    fi

    local worker_name
    worker_name=$(build_worker_name)

    USER_ID=$(id -u)
    GROUP_ID=$(id -g)

    local tool_run_cmds
    tool_run_cmds=$(get_package_run_cmds)

    local cmd="opencode"
    if [ -n "$tool_run_cmds" ]; then
        if echo "$tool_run_cmds" | grep -q '&'; then
            cmd="${tool_run_cmds} exec opencode"
        else
            cmd="${tool_run_cmds} & exec opencode"
        fi
    fi

    docker run --rm $interactive \
            --name "${worker_name}.agentstrator" \
            --network agentstrator-net \
            -w /workspace \
            $volumes_str \
            $env_vars \
            $tool_ports \
            -u "${USER_ID}:${GROUP_ID}" \
            $(get_runtime_base_image) \
            bash -c "$cmd"
}

run_shell_mode() {
    local tool_path
    tool_path=$(build_package_paths)

    run_package_inits "$WORKSPACE" "$VOLUME_DIR"

    ensure_network

    ensure_volume_structure

    local volumes_str
    volumes_str=$(build_volumes_str)

    local additional_path
    additional_path=$(build_path_str "$tool_path")

    local env_vars
    env_vars=$(build_env_vars "$additional_path" "" "/workspace")

    local tool_ports
    tool_ports=$(get_package_ports)

    local tool_run_cmds
    tool_run_cmds=$(get_package_run_cmds)

    local cmd="bash"
    if [ -n "$tool_run_cmds" ]; then
        if echo "$tool_run_cmds" | grep -q '&'; then
            cmd="${tool_run_cmds} exec bash"
        else
            cmd="${tool_run_cmds} & exec bash"
        fi
    fi

    USER_ID=$(id -u)
    GROUP_ID=$(id -g)

    local interactive="-it"
    if [[ -t 0 ]]; then
        interactive="-it"
    else
        interactive="-t"
    fi

    echo "Starting interactive shell..."
    docker run --rm $interactive \
        --network agentstrator-net \
        -w /workspace \
        $volumes_str \
        $env_vars \
        $tool_ports \
        -u "${USER_ID}:${GROUP_ID}" \
        $(get_runtime_base_image) \
        bash -c "$cmd"
}

run_server_mode() {
    local worker_name="${1:-$(build_worker_name)}"

    if [[ "$registry_url" == file://* ]]; then
        local reg_file="${registry_url#file://}"
        if [[ ! -f "$reg_file" ]] || [[ ! -s "$reg_file" ]]; then
            echo '{"agents": []}' > "$reg_file"
        fi
    fi

    local host_port=$(find_free_port 8080)
    if [[ $? -ne 0 ]]; then
        echo "$host_port"
        exit 1
    fi

    local tool_path
    tool_path=$(build_package_paths)

    echo "Starting worker '$worker_name' in Server mode on port $host_port..."

    run_package_inits "$WORKSPACE" "$VOLUME_DIR"

    ensure_volume_structure

    local config_dir="$VOLUME_DIR/.config/opencode"
    mkdir -p "$config_dir"
    if [ -f "$config_dir/opencode.json" ]; then
        cp "$config_dir/opencode.json" "$config_dir/opencode-server.json"
    else
        echo '{"settings":{}}' > "$config_dir/opencode-server.json"
    fi

    add_permission_to_opencode "$VOLUME_DIR" "opencode-server.json" "question" "deny"

    if ! docker network inspect agentstrator-net >/dev/null 2>&1; then
        echo "Warning: Docker network 'agentstrator-net' not found. Creating..."
        docker network create agentstrator-net >/dev/null 2>&1 || {
            echo "ERROR: Failed to create Docker network. Run agentstrator services start first."
            exit 1
        }
    fi

    local container_hostname="${worker_name}.agentstrator"
    local agent_url="http://${container_hostname}:8080"

    local registry_url
    registry_url=$(get_registry_url)

    if ! register_with_registry "$worker_name" "$agent_url" "$registry_url"; then
        echo "ERROR: Failed to register. Exiting."
        exit 1
    fi

    send_heartbeat "$worker_name" "$registry_url" &
    HEARTBEAT_PID=$!
    trap "kill $HEARTBEAT_PID 2>/dev/null; deregister_from_registry '$worker_name' '$registry_url'" EXIT

    local volumes_str
    volumes_str=$(build_volumes_str)

    local additional_path
    additional_path=$(build_path_str "$tool_path")

    local extra_envs=" \
        -e AGENT_NAME=\"$worker_name\" \
        -e AGENT_URL=\"$agent_url\" \
        -e REGISTRY_URL=\"$registry_url\""
    local env_vars
    env_vars=$(build_env_vars "$additional_path" "$extra_envs" "/workspace" "/agentstrator/.config/opencode/opencode-server.json")

    local tool_ports
    tool_ports=$(get_package_ports)

    echo "Starting opencode server on port $host_port..."
    echo "Worker URL (internal): $agent_url"
    echo "Worker URL (external): http://localhost:${host_port}"
    echo ""
    echo "To stop: Ctrl+C"
    echo ""

local interactive="-it"
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        interactive="-it"
    elif [[ -t 0 ]]; then
        interactive="-i"
    elif [[ -t 1 ]]; then
        interactive="-t"
    else
        interactive=""
    fi

    USER_ID=$(id -u)
    GROUP_ID=$(id -g)

    local tool_run_cmds
    tool_run_cmds=$(get_package_run_cmds)

    local cmd="opencode serve --hostname 0.0.0.0 --port 8080"
    if [ -n "$tool_run_cmds" ]; then
        if echo "$tool_run_cmds" | grep -q '&'; then
            cmd="${tool_run_cmds} exec ${cmd}"
        else
            cmd="${tool_run_cmds} & exec ${cmd}"
        fi
    fi

    docker run --rm $interactive \
        --name "$container_hostname" \
        --network agentstrator-net \
        -p "${host_port}:8080" \
        -w /workspace \
        $volumes_str \
        $env_vars \
        $tool_ports \
        -u "${USER_ID}:${GROUP_ID}" \
        $(get_runtime_base_image) \
        bash -c "$cmd"
}

# ============================================================
# Dev container modes
# ============================================================

run_dev_container_mode() {
    if [ -n "$DEV_CONTAINER" ] && [ -n "$DEV_MODE" ]; then
        case "$DEV_MODE" in
            cli)
                run_dev_container_cli
                exit $?
                ;;
            srv)
                run_dev_container_server
                exit $?
                ;;
            *) 
                echo "ERROR: Invalid --mode '$DEV_MODE'. Use 'cli' or 'srv'"
                exit 1
                ;;
        esac
    fi

    DEV_CONTAINER=""

    local mapping_file="$HOME/.agentstrator/dev-containers.json"
    mkdir -p "$(dirname "$mapping_file")"
    [ -f "$mapping_file" ] || echo '{}' > "$mapping_file"

    local default_name=""
    default_name=$(jq -r --arg dir "$WORKSPACE" '.[$dir] // empty' "$mapping_file" 2>/dev/null)

    if [ -n "$default_name" ]; then
        if ! docker inspect --format '{{.State.Running}}' "$default_name" &>/dev/null; then
            default_name=""
            jq --arg dir "$WORKSPACE" 'del(.[$dir])' "$mapping_file" > "${mapping_file}.tmp" && mv "${mapping_file}.tmp" "$mapping_file"
        fi
    fi

    if [ -n "$default_name" ]; then
        if whiptail --title "Dev Container" --yesno \
            "Use previous container '$default_name'?" 10 50; then
            DEV_CONTAINER="$default_name"
        else
            select_container || exit 1
            DEV_CONTAINER="$ATTACH_CONTAINER"
        fi
    else
        select_container || exit 1
        DEV_CONTAINER="$ATTACH_CONTAINER"
    fi

    [ -z "$DEV_CONTAINER" ] && echo "ERROR: No dev container selected" && exit 1

    jq --arg dir "$WORKSPACE" --arg container "$DEV_CONTAINER" '.[$dir] = $container' "$mapping_file" > "${mapping_file}.tmp" && mv "${mapping_file}.tmp" "$mapping_file"

    local mode
    mode=$(whiptail --title "Dev Container Mode" --menu \
        "Select execution mode:" 12 80 2 \
        "1" "Dev Container Client Mode - Run opencode interactively" \
        "2" "Dev Container Server Mode - Run opencode server" \
        3>&1 1>&2 2>&3)

    [ $? -ne 0 ] && exit 1

    case "$mode" in
        1)
            run_dev_container_cli
            exit $?
            ;;
        2)
            run_dev_container_server
            exit $?
            ;;
        *) exit 1 ;;
    esac
}

run_dev_container_cli() {
    local container_mounts
    container_mounts=$(docker inspect --format '{{json .Mounts}}' "$DEV_CONTAINER")

    local volumes_str=""
    local workdir="/workspace"

    for row in $(echo "$container_mounts" | jq -r '.[] | select(.Type == "volume") | .Name + ":" + .Destination'); do
        [ -z "$row" ] || [ "$row" = ":" ] && continue
        volumes_str="$volumes_str -v $row"
    done

    for row in $(echo "$container_mounts" | jq -r '.[] | select(.Type == "bind") | .Source + ":" + .Destination'); do
        [ -z "$row" ] || [ "$row" = ":" ] && continue
        volumes_str="$volumes_str -v $row"
    done

    local container_workdir
    container_workdir=$(docker inspect --format '{{.Config.WorkingDir}}' "$DEV_CONTAINER")
    [ -n "$container_workdir" ] && workdir="$container_workdir"

    # Check for --workdir override or show interactive menu
    if [ -n "$DEV_WORKDIR" ]; then
        # Use the provided workdir
        workdir="$DEV_WORKDIR"
        echo "Using working directory: $workdir"
    else
        # Ask user for working directory
        local selected_workdir
        selected_workdir=$(select_working_dir "$DEV_CONTAINER")
        if [ $? -ne 0 ]; then
            echo "Working directory selection cancelled."
            exit 1
        fi

        if [ "$selected_workdir" = "__DEFAULT__" ]; then
            selected_workdir="$workdir"
        fi
        workdir="$selected_workdir"
    fi

    local host_workspace="$WORKSPACE"
    for row in $(echo "$container_mounts" | jq -r '.[] | select(.Type == "bind") | .Source + ":" + .Destination'); do
        [ -z "$row" ] || [ "$row" = ":" ] && continue
        local src dest
        src="${row%%:*}"
        dest="${row##*:}"
        if [ "$dest" = "$workdir" ]; then
            host_workspace="$src"
            break
        fi
    done

    run_package_inits "$host_workspace" "$VOLUME_DIR"

    volumes_str="${volumes_str} -v ${VOLUME_DIR}:/agentstrator"

    local tool_path
    tool_path=$(build_package_paths)

    local additional_path
    additional_path=$(build_path_str "$tool_path")
    local package_commands
    package_commands=$(get_package_commands)

    # Container-specific config and instruction files
    local safe_container_name
    safe_container_name=$(echo "$DEV_CONTAINER" | tr '/' '-' | tr ' ' '-')
    local config_file="opencode-dev-${safe_container_name}.json"
    local instruction_file="dev-container-${safe_container_name}.md"

    local config_dir="$VOLUME_DIR/.config/opencode"
    mkdir -p "$config_dir"

    # Create container-specific config file
    if [ -f "$config_dir/opencode.json" ]; then
        cp "$config_dir/opencode.json" "$config_dir/$config_file"
    else
        echo '{"settings":{}}' > "$config_dir/$config_file"
    fi

    local env_vars
    env_vars=$(build_env_vars "$additional_path" "-e DEV_CONTAINER=$DEV_CONTAINER" "$workdir" "/agentstrator/.config/opencode/$config_file")

    # Generate instructions for the agent about dev container usage
    generate_dev_container_instructions "$VOLUME_DIR" "$DEV_CONTAINER" "$package_commands" "$instruction_file" "$config_file"
    # Remove old custom bash tool if exists
    rm -f "$VOLUME_DIR/.opencode/tools/bash.ts"

    # Cleanup generated files on exit
    trap "rm -f '$config_dir/$config_file' '$VOLUME_DIR/.config/opencode/$instruction_file'" EXIT

    ensure_network

    local dev_container_networks
    dev_container_networks=$(docker inspect --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' "$DEV_CONTAINER" 2>/dev/null)
    local extra_networks=""
    for net in $dev_container_networks; do
        if [[ "$net" != "host" && "$net" != "none" && "$net" != "bridge" && "$net" != "agentstrator-net" && -n "$net" ]]; then
            echo "Adding agentstrator container to network '$net'..."
            extra_networks="$extra_networks --network $net"
        fi
    done

    USER_ID=$(id -u)
    GROUP_ID=$(id -g)

    # Check if stdin is a terminal - OpenCode TUI needs real terminal
    # If not in a terminal, print error but continue (let user see the terminal issue themselves)
    if [[ ! -t 0 ]]; then
        echo ""
        echo "WARNING: Not running in a terminal. client mode requires a real TTY."
        echo "         Use --mode srv instead: agentstrator --dev <container> --mode srv"
        echo "         Or run agentstrator from a proper terminal."
        echo ""
    fi

    local interactive="-it"
    if [[ -t 0 ]]; then
        interactive="-it"
    else
        interactive="-t"
    fi

    local tool_run_cmds
    tool_run_cmds=$(get_package_run_cmds)

    local cmd="opencode"
    if [ -n "$tool_run_cmds" ]; then
        if echo "$tool_run_cmds" | grep -q '&'; then
            cmd="${tool_run_cmds} exec opencode"
        else
            cmd="${tool_run_cmds} & exec opencode"
        fi
    fi

    echo "Starting OpenCode in Dev Container Mode..."
    echo "Dev container: $DEV_CONTAINER"
    echo "Volumes: replicated from dev container"
    echo "Press Ctrl+C to stop"
    echo ""

    local docker_group
    docker_group=$(getent group docker 2>/dev/null | cut -d: -f3)
    [ -z "$docker_group" ] && docker_group=""

    local group_flag=""
    [ -n "$docker_group" ] && group_flag="--group-add $docker_group"

    docker run --rm $interactive \
        --name "${DEV_CONTAINER}.agentstrator" \
        --network agentstrator-net \
        $extra_networks \
        -w "$workdir" \
        $volumes_str \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$(which docker):/usr/bin/docker" \
        $env_vars \
        -u "${USER_ID}:${GROUP_ID}" \
        $group_flag \
        -e DEV_CONTAINER="$DEV_CONTAINER" \
        $(get_runtime_base_image) \
        bash -c "$cmd"
}

run_dev_container_server() {
    local container_mounts
    container_mounts=$(docker inspect --format '{{json .Mounts}}' "$DEV_CONTAINER")

    local volumes_str=""
    local workdir="/workspace"

    for row in $(echo "$container_mounts" | jq -r '.[] | select(.Type == "volume") | .Name + ":" + .Destination'); do
        [ -z "$row" ] || [ "$row" = ":" ] && continue
        volumes_str="$volumes_str -v $row"
    done

    for row in $(echo "$container_mounts" | jq -r '.[] | select(.Type == "bind") | .Source + ":" + .Destination'); do
        [ -z "$row" ] || [ "$row" = ":" ] && continue
        volumes_str="$volumes_str -v $row"
    done

    local container_workdir
    container_workdir=$(docker inspect --format '{{.Config.WorkingDir}}' "$DEV_CONTAINER")
    [ -n "$container_workdir" ] && workdir="$container_workdir"

    # Check for --workdir override or show interactive menu
    if [ -n "$DEV_WORKDIR" ]; then
        # Use the provided workdir
        workdir="$DEV_WORKDIR"
        echo "Using working directory: $workdir"
    else
        # Ask user for working directory
        local selected_workdir
        selected_workdir=$(select_working_dir "$DEV_CONTAINER")
        if [ $? -ne 0 ]; then
            echo "Working directory selection cancelled."
            exit 1
        fi

        if [ "$selected_workdir" = "__DEFAULT__" ]; then
            selected_workdir="$workdir"
        fi
        workdir="$selected_workdir"
    fi

    local host_workspace="$WORKSPACE"
    for row in $(echo "$container_mounts" | jq -r '.[] | select(.Type == "bind") | .Source + ":" + .Destination'); do
        [ -z "$row" ] || [ "$row" = ":" ] && continue
        local src dest
        src="${row%%:*}"
        dest="${row##*:}"
        if [ "$dest" = "$workdir" ]; then
            host_workspace="$src"
            break
        fi
    done

    run_package_inits "$host_workspace" "$VOLUME_DIR"

    volumes_str="${volumes_str} -v ${VOLUME_DIR}:/agentstrator"

    local tool_path
    tool_path=$(build_package_paths)

    local additional_path
    additional_path=$(build_path_str "$tool_path")
    local package_commands
    package_commands=$(get_package_commands)

    # Container-specific config and instruction files
    local safe_container_name
    safe_container_name=$(echo "$DEV_CONTAINER" | tr '/' '-' | tr ' ' '-')
    local config_file="opencode-dev-${safe_container_name}.json"
    local instruction_file="dev-container-${safe_container_name}.md"

    local config_dir="$VOLUME_DIR/.config/opencode"
    mkdir -p "$config_dir"

    if [ -f "$config_dir/opencode.json" ]; then
        cp "$config_dir/opencode.json" "$config_dir/$config_file"
    else
        echo '{"settings":{}}' > "$config_dir/$config_file"
    fi
    add_permission_to_opencode "$VOLUME_DIR" "$config_file" "question" "deny"

    # Generate instructions for the agent about dev container usage
    generate_dev_container_instructions "$VOLUME_DIR" "$DEV_CONTAINER" "$package_commands" "$instruction_file"

    local env_vars
    env_vars=$(build_env_vars "$additional_path" "-e DEV_CONTAINER=$DEV_CONTAINER" "$workdir" "/agentstrator/.config/opencode/$config_file")

    # Cleanup generated files on exit
    trap "rm -f '$config_dir/$config_file' '$VOLUME_DIR/.config/opencode/$instruction_file'; kill $heartbeat_pid 2>/dev/null; deregister_from_registry '$agent_container' '$registry_url'" EXIT

    ensure_network

    local dev_container_networks
    dev_container_networks=$(docker inspect --format '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' "$DEV_CONTAINER" 2>/dev/null)
    local extra_networks=""
    for net in $dev_container_networks; do
        if [[ "$net" != "host" && "$net" != "none" && "$net" != "bridge" && "$net" != "agentstrator-net" && -n "$net" ]]; then
            echo "Adding agentstrator container to network '$net'..."
            extra_networks="$extra_networks --network $net"
        fi
    done

    local host_port=$(find_free_port 8080)

    USER_ID=$(id -u)
    GROUP_ID=$(id -g)

    if [ -n "$DEV_CONTAINER" ]; then
        local container_user
        container_user=$(docker inspect --format '{{.Config.User}}' "$DEV_CONTAINER" 2>/dev/null || echo "")
        if [ -n "$container_user" ]; then
            if [ "$container_user" = "$(echo "$container_user" | tr -d ' ')" ] && [ -n "$container_user" ]; then
                local uid gid
                uid="${container_user%%:*}"
                gid="${container_user##*:}"
                if [ "$uid" != "$gid" ]; then
                    USER_ID="$uid"
                    GROUP_ID="$gid"
                else
                    USER_ID="$uid"
                    GROUP_ID="$uid"
                fi
            fi
        fi
    fi

    local agent_container="${DEV_CONTAINER}.agentstrator"

    local agent_url="http://${agent_container}:8080"

    local registry_url
    registry_url=$(get_registry_url)

    register_with_registry "$agent_container" "$agent_url" "$registry_url" || true

    send_heartbeat "$agent_container" "$registry_url" &
    local heartbeat_pid=$!

    echo "Starting OpenCode Server in Dev Container Mode..."
    echo "Dev container: $DEV_CONTAINER"
    echo "Agent container: $agent_container"
    echo "Agent URL (internal): $agent_url"
    echo "Agent URL (external): http://localhost:${host_port}"
    echo "Press Ctrl+C to stop"
    echo ""

    local docker_group
    docker_group=$(getent group docker 2>/dev/null | cut -d: -f3)
    [ -z "$docker_group" ] && docker_group=""

    local group_flag=""
    [ -n "$docker_group" ] && group_flag="--group-add $docker_group"

    # Check if stdin/stdout are TTYs
    local tty_flag="-it"
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        tty_flag="-it"
    elif [[ -t 0 ]]; then
        tty_flag="-i"
    elif [[ -t 1 ]]; then
        tty_flag="-t"
    else
        tty_flag=""
    fi

    docker run --rm $tty_flag \
        --name "$agent_container" \
        --network agentstrator-net \
        $extra_networks \
        -p "${host_port}:8080" \
        -w "$workdir" \
        $volumes_str \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$(which docker):/usr/bin/docker" \
        $env_vars \
        $group_flag \
        -u "${USER_ID}:${GROUP_ID}" \
        -e DEV_CONTAINER="$DEV_CONTAINER" \
        $(get_runtime_base_image) \
        bash -c "opencode serve --hostname 0.0.0.0 --port 8080"
}
