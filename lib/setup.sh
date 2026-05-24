#!/bin/bash
#
# lib/setup.sh — Setup-related functions extracted from agentstrator
# Depends on: COMMONS_SH (sourced for env_set), CONFIG_FILE, SCRIPT_DIR,
#             AGENTSTRATOR_INSTALL_DIR, AGENTSTRATOR_INSTALL_BIN,
#             AGENTSTRATOR_VOLUME, INSTALL_SOURCE_DIR, REMOTE_MODE
#

# Export required variables for sourced scripts
export AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
export CONFIG_FILE="${AGENTSTRATOR_INSTALL_DIR}/config.json"
export ENV_FILE="${AGENTSTRATOR_INSTALL_DIR}/.env"
export VOLUME_DIR="${AGENTSTRATOR_INSTALL_DIR}/volume"

# Source commons.sh - prefer installed, fall back to source
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
elif [ -f "$SCRIPT_DIR/../commons.sh" ]; then
    source "$SCRIPT_DIR/../commons.sh"
fi

# Source config.sh for get_config
if [ -f "$AGENTSTRATOR_INSTALL_DIR/lib/config.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/lib/config.sh"
elif [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
fi

# ============================================================
# Registry / Config helpers
# ============================================================

# Get current registry URL from .env file.
# Usage: url=$(get_current_registry_url)
get_current_registry_url() {
    local env_file="$AGENTSTRATOR_INSTALL_DIR/.env"
    if [ -f "$env_file" ]; then
        grep "^REGISTRY_URL=" "$env_file" 2>/dev/null | cut -d'=' -f2-
    fi
}

# Save registry configuration to .env file.
# Usage: save_registry_config "single" "file:///path/registry.json"
save_registry_config() {
    local mode="$1"
    local url="$2"
    local env_file="$AGENTSTRATOR_INSTALL_DIR/.env"

    if [ "$mode" = "single" ]; then
        env_set "$env_file" "REGISTRY_URL" "$url"
    elif [ "$mode" = "local" ]; then
        env_set "$env_file" "REGISTRY_URL" "http://localhost:8090"
    elif [ "$mode" = "remote" ]; then
        env_set "$env_file" "REGISTRY_URL" "$url"
    fi
}

# ============================================================
# Package / Service metadata helpers
# ============================================================

# Get package name from metadata file.
# Usage: name=$(get_package_name "rtk")
get_package_name() {
    local tool="$1"
    local source_dir="$SCRIPT_DIR"

    if [ "$tool" = "core" ] && [ -f "$source_dir/core/metadata" ]; then
        grep "^NAME=" "$source_dir/core/metadata" | cut -d'=' -f2- | xargs
        return
    fi

    local metadata_file="$source_dir/packages/$tool/metadata"
    if [ ! -f "$metadata_file" ]; then
        metadata_file="$AGENTSTRATOR_INSTALL_DIR/packages/$tool/metadata"
    fi
    if [ -f "$metadata_file" ]; then
        grep "^NAME=" "$metadata_file" | cut -d'=' -f2- | xargs
    else
        echo "$tool" | xargs
    fi
}

# Get package description from metadata file.
# Usage: desc=$(get_package_description "rtk")
get_package_description() {
    local tool="$1"
    local source_dir="$SCRIPT_DIR"

    if [ "$tool" = "core" ] && [ -f "$source_dir/core/metadata" ]; then
        grep "^DESCRIPTION=" "$source_dir/core/metadata" | cut -d'=' -f2- | xargs
        return
    fi

    local metadata_file="$source_dir/packages/$tool/metadata"
    if [ ! -f "$metadata_file" ]; then
        metadata_file="$AGENTSTRATOR_INSTALL_DIR/packages/$tool/metadata"
    fi
    if [ -f "$metadata_file" ]; then
        grep "^DESCRIPTION=" "$metadata_file" | cut -d'=' -f2- | xargs
    else
        echo "$tool" | xargs
    fi
}

# Get package path from metadata file.
# Usage: path=$(get_package_path "rtk")
get_package_path() {
    local tool="$1"
    local source_dir="$SCRIPT_DIR"

    if [ "$tool" = "core" ] && [ -f "$source_dir/core/metadata" ]; then
        grep "^PATH=" "$source_dir/core/metadata" | cut -d'=' -f2- | xargs
        return
    fi

    local metadata_file="$source_dir/packages/$tool/metadata"
    if [ -f "$metadata_file" ]; then
        grep "^PATH=" "$metadata_file" | cut -d'=' -f2- | xargs
    fi
}

# Get service name (with special handling for telegram/discord).
# Usage: name=$(get_service_name "telegram")
get_service_name() {
    local service="$1"
    local service_name
    service_name="$(basename "$service")"
    case "$service_name" in
        telegram) echo "telegram" ;;
        discord) echo "discord" ;;
        *)
            local metadata_file="$SCRIPT_DIR/services/$service_name/metadata"
            if [ -f "$metadata_file" ]; then
                grep "^NAME=" "$metadata_file" | cut -d'=' -f2- | xargs
            else
                echo "$service_name" | xargs
            fi
            ;;
    esac
}

# Get service path from metadata.
# Usage: path=$(get_service_path "telegram")
get_service_path() {
    local service="$1"
    local service_name
    service_name="$(basename "$service")"
    local metadata_file="$SCRIPT_DIR/services/$service_name/metadata"
    if [ -f "$metadata_file" ]; then
        grep "^PATH=" "$metadata_file" | cut -d'=' -f2- | xargs
    fi
}

# Get service description from metadata.
# Usage: desc=$(get_service_description "telegram")
get_service_description() {
    local service="$1"
    local metadata_file="$SCRIPT_DIR/services/$service/metadata"
    if [ -f "$metadata_file" ]; then
        grep "^DESCRIPTION=" "$metadata_file" | cut -d'=' -f2-
    else
        echo "$service"
    fi
}

# ============================================================
# Service discovery
# ============================================================

# List available services (excludes registry).
# Usage: services=$(list_services)
list_services() {
    local SOURCE_DIR="$SCRIPT_DIR"
    if [ ! -d "$SOURCE_DIR/services" ] && [ -d "$AGENTSTRATOR_INSTALL_DIR/services" ]; then
        SOURCE_DIR="$AGENTSTRATOR_INSTALL_DIR"
    fi

    local services_dir="$SOURCE_DIR/services"
    [ -d "$services_dir" ] || return

    for service in "$services_dir"/*/; do
        [ -d "$service" ] || continue
        local service_name
        service_name="$(basename "$service")"
        if [[ "$service_name" == "registry" ]]; then
            continue
        fi
        echo "$service_name"
    done | sort
}

# ============================================================
# Installation state checks
# ============================================================

# Check if a package is installed.
# Usage: is_installed "rtk"
is_installed() {
    local tool_dir="$1"
    if [ "$tool_dir" = "core" ]; then
        name="core"
    else
        name=$(get_package_name "$tool_dir")
    fi
    local config
    config=$(get_config 2>/dev/null || echo "{}")
    echo "$config" | jq -r ".\"$name\".installed // false" 2>/dev/null | grep -q "true" && echo "true" || echo "false"
}

# Check if a service is installed.
# Usage: is_service_installed "telegram" [$config]
is_service_installed() {
    local service_dir="$1"
    local config="${2:-}"
    [ -z "$config" ] && config=$(get_config 2>/dev/null || echo "{}")
    local name
    name=$(get_service_name "$service_dir")
    echo "$config" | jq -r ".\"$name\".installed // false" 2>/dev/null | grep -q "true" && echo "true" || echo "false"
}

# ============================================================
# Config initialization
# ============================================================

# Initialize config in memory (for menu display).
# Does NOT write to disk - only generates JSON structure.
# Use only for reading during setup wizard.
generate_config_template() {
    local source_dir="$SCRIPT_DIR"
    if [ ! -d "$source_dir/core" ] && [ -d "$AGENTSTRATOR_INSTALL_DIR/core" ]; then
        source_dir="$AGENTSTRATOR_INSTALL_DIR"
    fi
    local packages_dir="$source_dir/packages"
    local services_dir="$source_dir/services"
    local core_dir="$source_dir/core"
    local config="{}"

    if [ -d "$core_dir" ]; then
        local core_name
        local core_path
        if [ -f "$core_dir/metadata" ]; then
            core_name=$(grep "^NAME=" "$core_dir/metadata" | cut -d'=' -f2-)
            core_path=$(grep "^PATH=" "$core_dir/metadata" | cut -d'=' -f2-)
        fi
        core_name="${core_name:-core}"
        config=$(echo "$config" | jq -s ".[0] + {\"$core_name\": {installed: false, path: \"$core_path\", type: \"package\"}}" 2>/dev/null || echo "$config")
    fi

    if [ -d "$packages_dir" ]; then
        for tool in "$packages_dir"/*/; do
            [ -d "$tool" ] || continue
            local tool_dir
            tool_dir="$(basename "$tool")"
            local name
            name=$(get_package_name "$tool_dir")
            local tool_path
            tool_path=$(get_package_path "$tool_dir")
            config=$(echo "$config" | jq -s ".[0] + {\"$name\": {installed: false, path: \"$tool_path\", type: \"package\"}}" 2>/dev/null || echo "$config")
        done
    fi

    if [ -d "$services_dir" ]; then
        for service_dir in "$services_dir"/*/; do
            [ -d "$service_dir" ] || continue
            local service_name
            service_name="$(basename "$service_dir")"
            local name
            name=$(get_service_name "$service_name")
            local service_path
            service_path=$(get_service_path "$service_name")
            config=$(echo "$config" | jq -s ".[0] + {\"$name\": {installed: false, path: \"$service_path\", type: \"service\"}}" 2>/dev/null || echo "$config")
        done
    fi

    echo "$config"
}

# Initialize the config file if it does not exist or is empty.
# Writes to disk - use only after setup wizard completes.
write_config_to_disk() {
    if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$AGENTSTRATOR_INSTALL_DIR/config.json.bak"
    fi
    local config
    config=$(generate_config_template)
    mkdir -p "$AGENTSTRATOR_INSTALL_DIR"
    echo "$config" > "$CONFIG_FILE"
}

# ============================================================
# Whiptail menu helpers
# ============================================================

# Show installation type selection menu.
# Usage: choice=$(show_installation_type_menu)
show_installation_type_menu() {
    local current_url
    current_url=$(get_current_registry_url)

    choice=$(whiptail --title "Installation Type" --menu \
        "Select installation type:" 15 60 2 \
        "1" "Single host - No registry service (file-based)" \
        "2" "Multiple hosts - Registry service required" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$choice" ]; then
        echo "CANCELLED"
        return
    fi

    echo "$choice"
}

# Show registry configuration selection menu.
# Usage: mode=$(show_registry_menu)
show_registry_menu() {
    choice=$(whiptail --title "Registry Configuration" --menu \
        "Select registry configuration:" 15 60 2 \
        "local" "Install registry service locally" \
        "remote" "Use existing remote registry" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$choice" ]; then
        echo "CANCELLED"
        return
    fi

    echo "$choice"
}

# Show remote URL input dialog.
# Usage: url=$(show_remote_url_input)
show_remote_url_input() {
    local current_url
    current_url=$(get_current_registry_url)
    [ -z "$current_url" ] && current_url="http://localhost:8090"

    input=$(whiptail --title "Remote Registry URL" --inputbox \
        "Enter the remote registry URL (e.g., http://192.168.1.100:8090):" \
        10 60 "$current_url" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$input" ]; then
        echo "CANCELLED"
        return
    fi

    echo "$input"
}

# Show a checklist of packages in a category.
# Usage: selected=$(show_category_checklist "Analytics" "rtk" "logger")
show_category_checklist() {
    local category="$1"
    shift
    local tools=("$@")

    local menu_options=()
    local idx=0

    for tool in "${tools[@]}"; do
        [ -z "$tool" ] && continue
        local tool_name
        tool_name=$(get_package_name "$tool")
        tool_description=$(get_package_description "$tool")

        local is_selected="off"
        if [ "$(is_installed "$tool")" = "true" ]; then
            is_selected="on"
        fi

        menu_options+=("$tool" "$tool_description" "$is_selected")
        idx=$((idx + 1))
    done

    if [ "$idx" -eq 0 ]; then
        return
    fi

    local height=$((idx + 7))
    [ "$height" -lt 12 ] && height=12
    [ "$height" -gt 20 ] && height=20

    local width=80
    local max_line=0
    for ((i=0; i<${#menu_options[@]}; i+=3)); do
        local line_len=$(( ${#menu_options[i]} + ${#menu_options[i+1]} + 16 ))
        [ "$line_len" -gt "$max_line" ] && max_line=$line_len
    done
    width=$((max_line < 60 ? 60 : max_line > 120 ? 120 : max_line))

    local result
    result=$(whiptail --title "$category" --checklist \
        "Select tools to install:" $height $width "$idx" \
        "${menu_options[@]}" 3>&1 1>&2 2>&3)
    local ret=$?

    if [ $ret -ne 0 ]; then
        echo "CANCELLED"
        return
    fi

    echo "$result"
}

# Show a checklist of available services (channels).
# Usage: selected=$(show_channels_checklist)
show_channels_checklist() {
    local menu_options=()
    local services
    services=$(list_services)

    if [ -z "$services" ]; then
        return
    fi

    local idx=0
    while IFS= read -r service; do
        [ -z "$service" ] && continue
        local service_name
        service_name=$(get_service_name "$service")
        local service_desc
        service_desc=$(get_service_description "$service")
        local is_selected="off"
        if [ "$(is_service_installed "$service")" = "true" ]; then
            is_selected="on"
        fi
        menu_options+=("$service" "$service_desc" "$is_selected")
        idx=$((idx + 1))
    done <<< "$services"

    if [ "$idx" -eq 0 ]; then
        return
    fi

    local height=$((idx + 7))
    [ "$height" -lt 12 ] && height=12
    [ "$height" -gt 20 ] && height=20

    local width=80
    local max_line=0
    for ((i=0; i<${#menu_options[@]}; i+=3)); do
        local line_len=$(( ${#menu_options[i]} + ${#menu_options[i+1]} + 10 ))
        [ "$line_len" -gt "$max_line" ] && max_line=$line_len
    done
    width=$((max_line < 60 ? 60 : max_line > 120 ? 120 : max_line))

    local result
    result=$(whiptail --title "Channels" --checklist \
        "Select channels to install:" $height $width "$idx" \
        "${menu_options[@]}" 3>&1 1>&2 2>&3)
    local ret=$?

    if [ $ret -ne 0 ]; then
        echo "CANCELLED"
        return
    fi

    echo "$result"
}

# ============================================================
# Remote installation helpers
# ============================================================

# Download agentstrator files for remote installation.
download_agentstrator_files() {
    echo "Downloading agentstrator files for remote installation..."

    mkdir -p "$INSTALL_SOURCE_DIR"/{core,packages,services}

    download_file "agentstrator" "$INSTALL_SOURCE_DIR/core/"
    download_file "commons.sh" "$INSTALL_SOURCE_DIR/core/"

    download_file "packages.json" "$INSTALL_SOURCE_DIR/"

    mkdir -p "$INSTALL_SOURCE_DIR/services/telegram"
    mkdir -p "$INSTALL_SOURCE_DIR/services/discord"
    mkdir -p "$INSTALL_SOURCE_DIR/services/registry"

    echo "Download complete."
}

# Download a single file from the GitHub raw URL.
# Usage: download_file "packages.json" "/tmp/agentstrator/"
download_file() {
    local filename="$1"
    local dest_dir="$2"
    local url="${RAW_BASE_URL:-https://raw.githubusercontent.com/supertorpe/agentstrator/main}/$filename"

    mkdir -p "$dest_dir"
    if curl -fsSL "$url" -o "$dest_dir/$filename"; then
        echo "Downloaded $filename"
    else
        echo "WARNING: Failed to download $filename from $url"
        touch "$dest_dir/$filename"
    fi
}

# ============================================================
# Interactive component menu
# ============================================================

# Main interactive component selection menu.
component_menu() {
    local SOURCE_DIR
    if [ "$REMOTE_MODE" = true ]; then
        download_agentstrator_files
        SOURCE_DIR="$INSTALL_SOURCE_DIR"
    else
        SOURCE_DIR="$SCRIPT_DIR"
        if [ ! -d "$SOURCE_DIR/packages" ] && [ -d "$AGENTSTRATOR_INSTALL_DIR/packages" ]; then
            SOURCE_DIR="$AGENTSTRATOR_INSTALL_DIR"
        fi
    fi

    local is_existing=false
    local config_content
    config_content=$(cat "$AGENTSTRATOR_INSTALL_DIR/config.json" 2>/dev/null)
    if [ -n "$config_content" ] && [ "$config_content" != "{}" ] && [ "$config_content" != "[]" ]; then
        is_existing=true
    fi

    local menu_file
    menu_file="$SOURCE_DIR/packages.json"
    local menu_json="[]"
    if [ -f "$menu_file" ]; then
        menu_json=$(cat "$menu_file")
    fi

    local cat_count
    cat_count=$(echo "$menu_json" | jq 'length' 2>/dev/null || echo 0)
    local source_packages_dir
    source_packages_dir="$SOURCE_DIR/packages"

    local all_selected_tools=""
    local all_selected_services=""

    local install_type
    local registry_mode_value=""
    local registry_url_value=""

    if [ "$is_existing" = "true" ]; then
        local env_file="$AGENTSTRATOR_INSTALL_DIR/.env"
        if [ -f "$env_file" ]; then
            local registry_url
            registry_url=$(grep "^REGISTRY_URL=" "$env_file" 2>/dev/null | cut -d'=' -f2-)
            if [[ "$registry_url" == "http://localhost:8090"* ]]; then
                install_type="2"
                registry_mode_value="local"
                registry_url_value="$registry_url"
            elif [[ "$registry_url" == file://* ]]; then
                install_type="1"
                registry_mode_value="single"
                registry_url_value="$registry_url"
            else
                install_type="2"
                registry_mode_value="remote"
                registry_url_value="$registry_url"
            fi
        else
            install_type="1"
            registry_mode_value="single"
            registry_url_value="file://$AGENTSTRATOR_INSTALL_DIR/registry.json"
        fi
    else
        install_type=$(show_installation_type_menu)
        if [ "$install_type" = "CANCELLED" ]; then
            echo "Installation cancelled."
            exit 0
        fi

        if [ "$install_type" = "2" ]; then
            local registry_mode
            registry_mode=$(show_registry_menu)
            if [ "$registry_mode" = "CANCELLED" ]; then
                echo "Installation cancelled."
                exit 0
            fi

            if [ "$registry_mode" = "remote" ]; then
                local registry_url
                registry_url=$(show_remote_url_input)
                if [ "$registry_url" = "CANCELLED" ]; then
                    echo "Installation cancelled."
                    exit 0
                fi
                registry_mode_value="remote"
                registry_url_value="$registry_url"
            else
                registry_mode_value="local"
                registry_url_value="http://localhost:8090"
            fi
        else
            registry_mode_value="single"
            registry_url_value="file://$AGENTSTRATOR_INSTALL_DIR/registry.json"
        fi
    fi

    local i=0
    while [ "$i" -lt "$cat_count" ]; do
        local category
        category=$(echo "$menu_json" | jq -r ".[$i].category")

        local tools_array=()
        while IFS= read -r tool; do
            [ -z "$tool" ] && continue
            if [ -d "$source_packages_dir/$tool" ]; then
                tools_array+=("$tool")
            fi
        done < <(echo "$menu_json" | jq -r ".[$i].packages[].name" 2>/dev/null)

        if [ ${#tools_array[@]} -gt 0 ]; then
            local selected
            selected=$(show_category_checklist "$category" "${tools_array[@]}")
            if [ "$selected" = "CANCELLED" ]; then
                echo "Installation cancelled."
                exit 0
            fi
            if [ -n "$selected" ]; then
                if [ -n "$all_selected_tools" ]; then
                    all_selected_tools="$all_selected_tools $selected"
                else
                    all_selected_tools="$selected"
                fi
            fi
        fi

        i=$((i + 1))
    done

    local channels_selected
    channels_selected=$(show_channels_checklist)
    if [ "$channels_selected" = "CANCELLED" ]; then
        echo "Installation cancelled."
        exit 0
    fi
    if [ -n "$channels_selected" ]; then
        all_selected_services="$channels_selected"
    fi

    process_selections "$all_selected_tools" "$all_selected_services"

    echo ""
    echo "========================================"
    echo "Installation complete!"
    echo ""
    echo "(Add $AGENTSTRATOR_INSTALL_BIN to your PATH for shorter commands)"
    echo "========================================"

    exit 0
}

# ============================================================
# Selection processing and changes
# ============================================================

# Process user selections from the component menu.
# Usage: process_selections "$tools" "$services"
process_selections() {
    local selected_tools="$1"
    local selected_services="$2"

    local source_dir="$SCRIPT_DIR"
    if [ ! -d "$source_dir/packages" ] && [ -d "$AGENTSTRATOR_INSTALL_DIR/packages" ]; then
        source_dir="$AGENTSTRATOR_INSTALL_DIR"
    fi

    if [ ! -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ] && [ -f "$source_dir/commons.sh" ]; then
        mkdir -p "$AGENTSTRATOR_INSTALL_DIR"
        cp -r "$source_dir/commons.sh" "$AGENTSTRATOR_INSTALL_DIR/"
    fi

    if [ -d "$source_dir" ]; then
        mkdir -p "$AGENTSTRATOR_INSTALL_BIN"
        [ -f "$source_dir/agentstrator" ] && cp "$source_dir/agentstrator" "$AGENTSTRATOR_INSTALL_BIN/"
        [ -f "$source_dir/agentstrator" ] && chmod +x "$AGENTSTRATOR_INSTALL_BIN/agentstrator"
    fi

    if [ ! -d "$AGENTSTRATOR_INSTALL_DIR/core" ] && [ -d "$source_dir/core" ]; then
        echo "Copying agentstrator components..."
        mkdir -p "$AGENTSTRATOR_INSTALL_DIR"
        mkdir -p "$AGENTSTRATOR_INSTALL_DIR/volume"

        cp -r "$source_dir/core" "$AGENTSTRATOR_INSTALL_DIR/"
        [ -d "$source_dir/packages" ] && cp -r "$source_dir/packages" "$AGENTSTRATOR_INSTALL_DIR/"
        [ -f "$source_dir/packages.json" ] && cp "$source_dir/packages.json" "$AGENTSTRATOR_INSTALL_DIR/"
        [ -d "$source_dir/services" ] && cp -r "$source_dir/services" "$AGENTSTRATOR_INSTALL_DIR/"

        if [ -d "$source_dir/lib" ]; then
            echo "Copying lib scripts..."
            cp -r "$source_dir/lib" "$AGENTSTRATOR_INSTALL_DIR/"
        fi

        find "$AGENTSTRATOR_INSTALL_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
        echo "Components copied."
    fi

    if [ -d "$source_dir/packages" ] && [ -d "$AGENTSTRATOR_INSTALL_DIR/packages" ]; then
        for pkg in "$source_dir/packages"/*/; do
            [ -d "$pkg" ] || continue
            local pkg_name
            pkg_name="$(basename "$pkg")"
            if [ ! -d "$AGENTSTRATOR_INSTALL_DIR/packages/$pkg_name" ]; then
                echo "Adding new package: $pkg_name"
                cp -r "$pkg" "$AGENTSTRATOR_INSTALL_DIR/packages/"
            fi
        done
    fi

    if ! docker network inspect agentstrator-net &>/dev/null; then
        echo "Creating agentstrator-net network..."
        docker network create agentstrator-net
    fi

    write_config_to_disk

    local previous_config
    if [ -f "$AGENTSTRATOR_INSTALL_DIR/config.json.bak" ]; then
        previous_config=$(cat "$AGENTSTRATOR_INSTALL_DIR/config.json.bak")
    else
        previous_config="{}"
    fi

    save_registry_config "$registry_mode_value" "$registry_url_value"

    local user_id=$(id -u)
    local group_id=$(id -g)
    local user_name=$(id -un 2>/dev/null || echo "user")
    local group_name=$(id -gn 2>/dev/null || echo "user")

    mkdir -p "$AGENTSTRATOR_INSTALL_DIR"

    cat > "$AGENTSTRATOR_INSTALL_DIR/group" <<EOF
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:
fax:x:21:
voice:x:22:
cdrom:x:24:
floppy:x:25:
tape:x:26:
sudo:x:27:
audio:x:29:
dip:x:30:
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
shadow:x:42:
utmp:x:43:
video:x:44:
sasl:x:45:
plugdev:x:46:
staff:x:50:
games:x:60:
users:x:100:
nogroup:x:65534:
${group_name}:x:${group_id}:
EOF

    cat > "$AGENTSTRATOR_INSTALL_DIR/passwd" <<EOF
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/spool/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/usr/sbin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/run/ircd:/usr/sbin/nologin
_apt:x:42:65534::/nonexistent:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
${user_name}:x:${user_id}:${group_id}:${user_name}:/agentstrator:/bin/bash
EOF

    echo "Installing core components..."
    local core_dir="$AGENTSTRATOR_INSTALL_DIR/core"
    if [ -d "$core_dir" ]; then
        if [ -f "$core_dir/install.sh" ]; then
            echo "Installing core..."
            AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" "$core_dir/install.sh"
        else
            for component in "$core_dir"/*/; do
                [ -d "$component" ] || continue
                local name
                name="$(basename "$component")"
                if [ -f "$component/install.sh" ]; then
                    echo "Installing core component: $name..."
                    AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" "$component/install.sh"
                fi
            done
        fi
    fi

    echo "Building agentstrator-core image..."
    build_core_image

    apply_changes "$selected_tools" "$selected_services" "$previous_config" "update_config"

    apply_changes "$selected_tools" "$selected_services" "$previous_config" "run_install"

    echo "Building runtime image..."
    build_runtime
}

# Apply changes: install selected packages and services.
# Usage: apply_changes "$tools" "$services" "$previous_config" ["update_config"|"run_install"]
apply_changes() {
    local selected_tools="$1"
    local selected_services="$2"
    local previous_config="${3:-{}}"
    local phase="${4:-both}"

    local config
    config=$(get_config)

    local parsed_services
    parsed_services=$(echo "$selected_services" | sed 's/"//g' | xargs)

    local services_dir="$AGENTSTRATOR_INSTALL_DIR/services"
    local bridges_selected=false

    if [ -n "$parsed_services" ]; then
        for service in $parsed_services; do
            [ -z "$service" ] && continue

            local service_dir=""
            case "$service" in
                telegram-bridge) service_dir="telegram" ;;
                discord-bridge) service_dir="discord" ;;
                *) service_dir="$service" ;;
            esac

            local was_installed
            was_installed=$(is_service_installed "$service_dir" "$previous_config")

            if [ "$was_installed" = "false" ]; then
                if [ "$phase" = "update_config" ]; then
                    if [ -f "$services_dir/$service_dir/install.sh" ]; then
                        :  # Skip install during config phase
                    fi
                else
                    if [ -f "$services_dir/$service_dir/install.sh" ]; then
                        echo "Installing $service..."
                        "$services_dir/$service_dir/install.sh"
                    else
                        echo "Warning: install.sh not found for $service_dir"
                    fi
                fi
            fi

            local name
            name=$(get_service_name "$service_dir")

            if [[ "$service" == *"bridge"* ]]; then
                bridges_selected=true
            fi

            if [ -z "$config" ] || [ "$config" = "{}" ]; then
                config="{}"
            fi

            config=$(echo "$config" | jq -s ".[0] + {\"$name\": {installed: true, type: \"service\"}}" 2>/dev/null || echo "$config")
        done
    fi

    if [ "$registry_mode_value" = "local" ]; then
        local was_registry_installed
        was_registry_installed=$(is_service_installed "registry" "$previous_config")
        if [ "$was_registry_installed" = "false" ]; then
            if [ "$phase" = "update_config" ]; then
                :  # Skip install during config phase
            else
                if [ -f "$services_dir/registry/install.sh" ]; then
                    echo "Installing Registry..."
                    "$services_dir/registry/install.sh"
                else
                    echo "Warning: install.sh not found for registry"
                fi
            fi
        fi
        local registry_name
        registry_name=$(get_service_name "registry")
        if [ -z "$config" ] || [ "$config" = "{}" ]; then
            config="{}"
        fi
        config=$(echo "$config" | jq -s ".[0] + {\"$registry_name\": {installed: true, type: \"service\"}}" 2>/dev/null || echo "$config")
    fi

    local parsed_tools
    parsed_tools=$(echo "$selected_tools" | sed 's/"//g' | xargs)

    if [ -n "$parsed_tools" ]; then
        for tool_display in $parsed_tools; do
            [ -z "$tool_display" ] && continue

            local name
            local install_script
            local tool_path

            if [ "$tool_display" = "core" ]; then
                name="core"
                install_script="$AGENTSTRATOR_INSTALL_DIR/core/install.sh"
                tool_path=$(grep "^PATH=" "$AGENTSTRATOR_INSTALL_DIR/core/metadata" | cut -d'=' -f2-)
            else
                name=$(get_package_name "$tool_display")
                tool_dir="$tool_display"
                install_script="$AGENTSTRATOR_INSTALL_DIR/packages/$tool_dir/install.sh"
                tool_path=$(get_package_path "$tool_dir")
            fi

            local was_installed
            was_installed=$(echo "$previous_config" | jq -r ".\"$name\".installed // false" 2>/dev/null | grep -q "true" && echo "true" || echo "false")
            local now_installed="true"

            if [ "$was_installed" = "false" ]; then
                if [ "$phase" = "update_config" ]; then
                    :  # Skip install during config phase
                else
                    # Build package Docker image before running install.sh
                    if [ "$tool_display" != "core" ] && [ -f "$AGENTSTRATOR_INSTALL_DIR/packages/$tool_dir/Dockerfile" ]; then
                        local pkg_image="agentstrator-$tool_dir"
                        # Remove old image to force rebuild
                        docker rmi "$pkg_image" 2>/dev/null || true
                        echo "  Building $pkg_image..."
                        docker build -t "$pkg_image" "$AGENTSTRATOR_INSTALL_DIR/packages/$tool_dir" || {
                            echo "ERROR: Failed to build $pkg_image"
                            exit 1
                        }
                    fi

                    if [ -f "$install_script" ]; then
                        echo "Installing $name..."
                        AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" "$install_script"
                    fi
                fi
            fi

            if [ -z "$config" ] || [ "$config" = "{}" ]; then
                config="{}"
            fi

            config=$(echo "$config" | jq -s ".[0] + {\"$name\": {installed: $now_installed, path: \"$tool_path\", type: \"package\"}}" 2>/dev/null || echo "$config")
        done
    fi

    local all_package_names=""
    for pkg in "$AGENTSTRATOR_INSTALL_DIR"/packages/*/; do
        [ -d "$pkg" ] || continue
        local pkg_basename
        pkg_basename="$(basename "$pkg")"
        local pkg_name
        pkg_name=$(get_package_name "$pkg_basename")
        all_package_names="$all_package_names $pkg_name"
    done

    if [ -n "$all_package_names" ]; then
        for pkg_name in $all_package_names; do
            [ -z "$pkg_name" ] && continue
            local was_installed
            was_installed=$(echo "$previous_config" | jq -r ".\"$pkg_name\".installed // false" 2>/dev/null | grep -q "true" && echo "true" || echo "false")

            local is_selected="false"
            if [ -n "$parsed_tools" ]; then
                for selected_tool in $parsed_tools; do
                    [ -z "$selected_tool" ] && continue
                    local selected_name
                    selected_name=$(get_package_name "$selected_tool")
                    if [ "$selected_name" = "$pkg_name" ]; then
                        is_selected="true"
                        break
                    fi
                done
            fi

            if [ "$was_installed" = "true" ] && [ "$is_selected" = "false" ]; then
                if [ "$phase" = "update_config" ]; then
                    :  # Skip uninstall during config phase
                else
                    local uninstall_script="$AGENTSTRATOR_INSTALL_DIR/packages/$pkg_name/uninstall.sh"
                    if [ -f "$uninstall_script" ]; then
                        echo "Uninstalling $pkg_name (deselected)..."
                        AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" "$uninstall_script" || true
                    fi
                fi
            fi
        done
    fi

    write_config "$config"
}

# ============================================================
# Uninstall
# ============================================================

# Uninstall agentstrator completely.
uninstall_agentstrator() {
    echo "=== agentstrator uninstall ==="
    echo ""

    VOLUME_DIR="$AGENTSTRATOR_INSTALL_DIR/volume"

    local components_with_uninstall=""
    local component_images=""

    _check_component() {
        local comp_dir="$1"
        local comp_type="$2"
        local name
        name="$(basename "$comp_dir")"

        local has_dockerfile=false
        if [ -f "$comp_dir/Dockerfile" ]; then
            has_dockerfile=true
        fi

        local image_name="agentstrator-${name}"
        local image_exists=false
        if docker image inspect "$image_name" &>/dev/null; then
            image_exists=true
            component_images="${component_images}${image_name} "
        fi

        if [ -f "$comp_dir/uninstall.sh" ]; then
            if [ "$has_dockerfile" = "true" ]; then
                if [ "$image_exists" = "true" ]; then
                    components_with_uninstall="${components_with_uninstall}${comp_type}:${name} "
                fi
            else
                local display_name
                display_name=$(get_package_name "$name")
                if [ -f "$AGENTSTRATOR_INSTALL_DIR/config.json" ]; then
                    local is_inst
                    is_inst=$(jq -r ".\"$display_name\".installed // false" "$AGENTSTRATOR_INSTALL_DIR/config.json" 2>/dev/null)
                    if [ "$is_inst" = "true" ]; then
                        components_with_uninstall="${components_with_uninstall}${comp_type}:${name} "
                    fi
                fi
            fi
        fi
    }

    if [ -d "$AGENTSTRATOR_INSTALL_DIR/core" ]; then
        if [ -f "$AGENTSTRATOR_INSTALL_DIR/core/install.sh" ]; then
            _check_component "$AGENTSTRATOR_INSTALL_DIR/core" "core"
        else
            for comp in "$AGENTSTRATOR_INSTALL_DIR/core"/*/; do
                [ -d "$comp" ] || continue
                _check_component "$comp" "core"
            done
        fi
    fi

    if [ -d "$AGENTSTRATOR_INSTALL_DIR/packages" ]; then
        for comp in "$AGENTSTRATOR_INSTALL_DIR/packages"/*/; do
            [ -d "$comp" ] || continue
            _check_component "$comp" "tool"
        done
    fi

    if [ -d "$AGENTSTRATOR_INSTALL_DIR/services" ]; then
        for comp in "$AGENTSTRATOR_INSTALL_DIR/services"/*/; do
            [ -d "$comp" ] || continue
            _check_component "$comp" "service"
        done
    fi

    # Check for runtime and core images
    if docker image inspect agentstrator:runtime &>/dev/null; then
        component_images="${component_images}agentstrator:runtime "
    fi
    if docker image inspect agentstrator-core &>/dev/null; then
        component_images="${component_images}agentstrator-core "
    fi
    if docker image inspect agentstrator-base &>/dev/null; then
        component_images="${component_images}agentstrator-base "
    fi
    if docker image inspect agentstrator-services &>/dev/null; then
        component_images="${component_images}agentstrator-services "
    fi

    local running_containers
    running_containers=$(docker ps -q --filter "network=agentstrator-net" 2>/dev/null || true)

    if [ -n "$running_containers" ]; then
        echo "ERROR: There are running containers on agentstrator-net:"
        docker ps --filter "network=agentstrator-net" --format "  - {{.Names}} ({{.Image}})" 2>/dev/null || true
        echo ""
        echo "Please stop them before uninstalling."
        exit 1
    fi

    echo "Will remove:"
    echo "  - $AGENTSTRATOR_INSTALL_DIR (including volume)"
    echo "  - $AGENTSTRATOR_INSTALL_BIN/agentstrator"
    echo "  - Docker network: agentstrator-net"

    if [ -n "$components_with_uninstall" ]; then
        echo "  - Component uninstall scripts:"
        for comp in $components_with_uninstall; do
            [ -z "$comp" ] && continue
            local type="${comp%%:*}"
            local name="${comp##*:}"
            local display_name
            display_name=$(get_package_name "$name")
            echo "    - ${type}:${display_name}"
        done
    fi

    if [ -n "$component_images" ]; then
        echo "  - Docker images:"
        for img in $component_images; do
            echo "    - $img"
        done
    fi

    echo ""
    read -p "Continue? [y/N] " confirm
    if [ "$confirm" != "y" ]; then
        echo "Cancelled."
        exit 0
    fi

    if [ -n "$components_with_uninstall" ]; then
        echo "Running component uninstall scripts..."
        for comp_info in $components_with_uninstall; do
            local type="${comp_info%%:*}"
            local name="${comp_info##*:}"
            local display_name
            display_name=$(get_package_name "$name")

            if [ "$type" = "core" ]; then
                if [ -f "$AGENTSTRATOR_INSTALL_DIR/core/uninstall.sh" ]; then
                    local uninstall_script="$AGENTSTRATOR_INSTALL_DIR/core/uninstall.sh"
                else
                    local uninstall_script="$AGENTSTRATOR_INSTALL_DIR/core/$name/uninstall.sh"
                fi
            else
                local uninstall_script="$AGENTSTRATOR_INSTALL_DIR/packages/$name/uninstall.sh"
            fi

            if [ -f "$uninstall_script" ]; then
                echo "  Uninstalling $display_name..."
                AGENTSTRATOR_VOLUME="$VOLUME_DIR" "$uninstall_script" || true
            fi
        done
    fi

    # Clean up any stale docker compose project state before removing network
    for project in agentstrator-registry agentstrator-discord agentstrator-telegram; do
        docker compose -p "$project" down --remove-orphans 2>/dev/null || true
    done

    if docker network inspect agentstrator-net &>/dev/null; then
        echo "Removing docker network agentstrator-net..."
        docker network rm agentstrator-net 2>/dev/null || true
    fi

    for img in $component_images; do
        if docker image inspect "$img" &>/dev/null; then
            echo "Removing docker image $img..."
            docker rmi "$img" 2>/dev/null || true
        fi
    done

    if [ -d "$AGENTSTRATOR_INSTALL_DIR" ]; then
        echo "Removing $AGENTSTRATOR_INSTALL_DIR..."
        rm -rf "$AGENTSTRATOR_INSTALL_DIR"
    fi

    if [ -f "$AGENTSTRATOR_INSTALL_BIN/agentstrator" ]; then
        echo "Removing $AGENTSTRATOR_INSTALL_BIN/agentstrator..."
        rm "$AGENTSTRATOR_INSTALL_BIN/agentstrator"
    fi

    echo ""
    echo "agentstrator uninstalled successfully."
}

# ============================================================
# Entry point
# ============================================================

# Entry point for the setup command.
# Usage: run_setup [--uninstall]
# Usage: run_setup
run_setup() {
    local args=("$@")

    # Check for --uninstall flag among the args
    local has_uninstall=false
    for arg in "${args[@]}"; do
        if [ "$arg" = "--uninstall" ]; then
            has_uninstall=true
            break
        fi
    done

    if [ "$has_uninstall" = "true" ]; then
        uninstall_agentstrator
        exit $?
    fi

    component_menu
}
