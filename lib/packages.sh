#!/bin/bash
#
# lib/packages.sh — Package Manager functions
# Reusable by any script that sources this file.
#
# Provides functions for managing agentstrator packages:
# installing, removing, upgrading, and listing packages.
#

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"

# Detect repo directory (where packages/, lib/, etc. are located)
if [ -z "$SCRIPT_DIR" ]; then
    # Try to find repo dir from agentstrator location
    if [ -f "$AGENTSTRATOR_INSTALL_DIR/../packages" ]; then
        SCRIPT_DIR="$(cd "$AGENTSTRATOR_INSTALL_DIR/.." && pwd)"
    elif [ -f "$AGENTSTRATOR_INSTALL_DIR/packages" ]; then
        SCRIPT_DIR="$AGENTSTRATOR_INSTALL_DIR"
    fi
fi

# ============================================================
# Package Manager functions
# ============================================================

# Read installed packages from config file.
# Usage: get_installed_packages
# Returns: newline-separated list of installed package names
get_installed_packages() {
    local config_file="$AGENTSTRATOR_INSTALL_DIR/config.json"
    if [ -f "$config_file" ]; then
        jq -r 'to_entries[] | select(.value.installed == true) | .key' "$config_file" 2>/dev/null || true
    fi
}

# Get package info from local files and packages.json.
# Usage: get_package_info <package_name>
# Returns: description, source, category as global vars
get_package_info() {
    local pkg_name="$1"
    PKG_DESCRIPTION="No description"
    PKG_SOURCE=""
    PKG_CATEGORY=""

    # Try to find package in packages.json and get category
    local packages_json=""
    if [ -f "$AGENTSTRATOR_INSTALL_DIR/packages.json" ]; then
        packages_json=$(cat "$AGENTSTRATOR_INSTALL_DIR/packages.json")
    elif [ -f "$SCRIPT_DIR/packages.json" ]; then
        packages_json=$(cat "$SCRIPT_DIR/packages.json")
    fi

    if [ -n "$packages_json" ]; then
        PKG_CATEGORY=$(echo "$packages_json" | jq -r --arg name "$pkg_name" \
            '.[] | .packages[] | select(.name == $name) | .category' 2>/dev/null | head -1)
    fi

    # Check for local metadata (installed packages or available locally)
    local metadata_file="$AGENTSTRATOR_INSTALL_DIR/packages/$pkg_name/metadata"
    if [ ! -f "$metadata_file" ] && [ -f "$SCRIPT_DIR/packages/$pkg_name/metadata" ]; then
        metadata_file="$SCRIPT_DIR/packages/$pkg_name/metadata"
    fi

    if [ -f "$metadata_file" ]; then
        PKG_DESCRIPTION=$(grep "^DESCRIPTION=" "$metadata_file" 2>/dev/null | cut -d'=' -f2- | xargs || echo "No description")
        PKG_SOURCE=$(grep "^SOURCE=" "$metadata_file" 2>/dev/null | cut -d'=' -f2- | xargs || echo "")
    fi
}

# List all packages with status info.
# Usage: list_packages
# Reads: $AGENTSTRATOR_INSTALL_DIR/packages.json
list_packages() {
    local packages_json=
    packages_json=$(cat "$AGENTSTRATOR_INSTALL_DIR/packages.json" 2>/dev/null)
    if [ -z "$packages_json" ]; then
        packages_json=$(cat "$SCRIPT_DIR/packages.json" 2>/dev/null)
    fi
    if [ -z "$packages_json" ]; then
        echo "ERROR: packages.json not found."
        return 1
    fi

    local installed
    installed=$(get_installed_packages)

    local cat_count
    cat_count=$(echo "$packages_json" | jq 'length' 2>/dev/null || echo 0)
    if [ "$cat_count" -eq 0 ] || [ "$cat_count" = "0" ]; then
        echo "ERROR: Invalid packages.json format."
        return 1
    fi

    echo ""

    for ((c=0; c<cat_count; c++)); do
        local category
        category=$(echo "$packages_json" | jq -r ".[$c].category")
        local pkg_count
        pkg_count=$(echo "$packages_json" | jq ".[$c].packages | length")

        [ "$category" = "Core" ] && continue

        echo ""
        echo "  $category"

        local wide=true
        [ "$category" = "Channels" ] && wide=false

        if [ "$wide" = "true" ]; then
            printf "  %-4s %-18s %-50s %s\n" "[ ]" "Package" "Description" "URL"
            echo "  ------------------------------------------------------------------------------------------"
        else
            printf "  %-4s %-18s\n" "[ ]" "Package"
            echo "  --------------------------------"
        fi

        for ((p=0; p<pkg_count; p++)); do
            local pkg_name
            pkg_name=$(echo "$packages_json" | jq -r ".[$c].packages[$p].name")

            [ "$pkg_name" = "core" ] && continue

            local mark=" "
            if echo "$installed" | grep -qx "$pkg_name"; then
                mark="x"
            fi

            if [ "$wide" = "true" ]; then
                get_package_info "$pkg_name"
                printf "  [%s] %-18s %-50s %s\n" "$mark" "$pkg_name" "$PKG_DESCRIPTION" "$PKG_SOURCE"
            else
                printf "  [%s] %-18s\n" "$mark" "$pkg_name"
            fi
        done
    done
    echo ""
}

# Show detailed information about a single package.
# Usage: info_package <package_name>
info_package() {
    local pkg_name="$1"
    if [ -z "$pkg_name" ]; then
        echo "Usage: agentstrator info <package>"
        return 1
    fi

    # Read packages.json from available locations
    local packages_json=""
    if [ -f "$AGENTSTRATOR_INSTALL_DIR/packages.json" ]; then
        packages_json=$(cat "$AGENTSTRATOR_INSTALL_DIR/packages.json")
    fi

    if [ -z "$packages_json" ]; then
        echo "ERROR: packages.json not found."
        return 1
    fi

    # Find package in JSON
    local pkg_info
    pkg_info=$(echo "$packages_json" | jq -r --arg name "$pkg_name" \
        '.[] | .packages[] | select(.name == $name)' 2>/dev/null)

    if [ -z "$pkg_info" ]; then
        echo "ERROR: Package '$pkg_name' not found in packages.json"
        return 1
    fi

    # Get category
    local category
    category=$(echo "$packages_json" | jq -r --arg name "$pkg_name" \
        '.[] | select(.packages[].name == $name) | .category' 2>/dev/null | head -1)

    # Check if installed
    local installed="no"
    local installed_packages
    installed_packages=$(get_installed_packages)
    if echo "$installed_packages" | grep -qx "$pkg_name"; then
        installed="yes"
    fi

    # Get metadata if available
    local description="No description"
    local source_url="https://github.com/supertorpe/agentstrator/tree/main/packages/$pkg_name"

    local metadata_file="$AGENTSTRATOR_INSTALL_DIR/packages/$pkg_name/metadata"

    if [ -f "$metadata_file" ]; then
        description=$(grep "^DESCRIPTION=" "$metadata_file" 2>/dev/null | cut -d'=' -f2- | xargs || echo "No description")
        local src
        src=$(grep "^SOURCE=" "$metadata_file" 2>/dev/null | cut -d'=' -f2- | xargs || echo "")
        if [ -n "$src" ]; then
            source_url="$src"
        fi
    fi

    echo ""
    echo "Package:    $pkg_name"
    echo "Category:   ${category:-Unknown}"
    echo "Description: $description"
    echo "Source:     $source_url"
    echo "Installed:  $installed"
    echo ""
}

# Install a package by name.
# Usage: install_package <package_name>
install_package() {
    local pkg_name="$1"
    if [ -z "$pkg_name" ]; then
        echo "Usage: agentstrator install <package>"
        return 1
    fi

    local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"
    local services_dir="$AGENTSTRATOR_INSTALL_DIR/services"
    local repo_dir="$SCRIPT_DIR"

    local pkg_dir=""
    local install_script=""

    # Check installed location first, then repo
    if [ -d "$services_dir/$pkg_name" ]; then
        pkg_dir="$services_dir/$pkg_name"
        install_script="$services_dir/$pkg_name/install.sh"
    elif [ -d "$packages_dir/$pkg_name" ]; then
        pkg_dir="$packages_dir/$pkg_name"
        install_script="$packages_dir/$pkg_name/install.sh"
    elif [ -d "$repo_dir/packages/$pkg_name" ]; then
        pkg_dir="$repo_dir/packages/$pkg_name"
        install_script="$repo_dir/packages/$pkg_name/install.sh"
    elif [ -d "$repo_dir/services/$pkg_name" ]; then
        pkg_dir="$repo_dir/services/$pkg_name"
        install_script="$repo_dir/services/$pkg_name/install.sh"
    else
        echo "ERROR: Package directory '$pkg_name' not found"
        return 1
    fi

    if [ ! -f "$install_script" ]; then
        echo "ERROR: install.sh not found for package '$pkg_name'"
        return 1
    fi

    # Build package Docker image first (needed before running install.sh)
    if [ -f "$pkg_dir/Dockerfile" ]; then
        echo "Building agentstrator-$pkg_name..."
        docker build -t "agentstrator-$pkg_name" "$pkg_dir" || {
            echo "ERROR: Failed to build agentstrator-$pkg_name"
            return 1
        }
    fi

    echo "Installing $pkg_name..."
    AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" "$install_script"

    local config
    config=$(cat "$AGENTSTRATOR_INSTALL_DIR/config.json" 2>/dev/null || echo "{}")
    local metadata_file="$pkg_dir/metadata"
    local pkg_path=""
    if [ -f "$metadata_file" ]; then
        pkg_path=$(grep "^PATH=" "$metadata_file" | cut -d'=' -f2- | xargs)
    fi
    pkg_name=$(echo "$pkg_name" | xargs)
    config=$(echo "$config" | jq -s ".[0] + {\"$pkg_name\": {installed: true, path: \"$pkg_path\", type: \"package\"}}" 2>/dev/null || echo "$config")
    echo "$config" > "$AGENTSTRATOR_INSTALL_DIR/config.json"

    # Rebuild runtime image
    echo "Rebuilding runtime image..."
    "$AGENTSTRATOR_INSTALL_DIR/lib/build-runtime.sh" build

    echo "Package $pkg_name installed successfully."
}

# Remove a package by name.
# Usage: remove_package <package_name>
remove_package() {
    local pkg_name="$1"
    if [ -z "$pkg_name" ]; then
        echo "Usage: agentstrator remove <package>"
        return 1
    fi

    local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"
    local services_dir="$AGENTSTRATOR_INSTALL_DIR/services"

    local uninstall_script=""
    if [ -f "$services_dir/$pkg_name/uninstall.sh" ]; then
        uninstall_script="$services_dir/$pkg_name/uninstall.sh"
    elif [ -f "$packages_dir/$pkg_name/uninstall.sh" ]; then
        uninstall_script="$packages_dir/$pkg_name/uninstall.sh"
    else
        echo "ERROR: uninstall.sh not found for package '$pkg_name'"
        return 1
    fi

    echo "Removing $pkg_name..."
    "$uninstall_script" || true

    local config
    config=$(cat "$AGENTSTRATOR_INSTALL_DIR/config.json" 2>/dev/null || echo "{}")
    config=$(echo "$config" | jq --arg name "$pkg_name" 'if .[$name] then .[$name].installed = false else . end' 2>/dev/null || echo "$config")
    echo "$config" > "$AGENTSTRATOR_INSTALL_DIR/config.json"

    # Rebuild runtime image
    echo "Rebuilding runtime image..."
    "$AGENTSTRATOR_INSTALL_DIR/lib/build-runtime.sh" build

    echo "Package $pkg_name removed successfully."
}

# Rebuild all installed packages (uninstall then install).
# Forces Docker rebuilds with --no-cache to pick up upstream changes.
# Usage: rebuild_packages
rebuild_packages() {
    local installed
    installed=$(get_installed_packages)

    if [ -z "$installed" ]; then
        echo "No packages installed."
        return
    fi

    local total=0
    local success=0
    local failed=0

    while IFS= read -r pkg_name; do
        [ -z "$pkg_name" ] && continue
        total=$((total + 1))
        echo "Rebuilding $pkg_name..."

        local packages_dir="$AGENTSTRATOR_INSTALL_DIR/packages"
        local uninstall_script="$packages_dir/$pkg_name/uninstall.sh"
        local install_script="$packages_dir/$pkg_name/install.sh"

        if [ -f "$uninstall_script" ]; then
            AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" "$uninstall_script" || true
        fi

        # Remove old Docker image to force rebuild
        local pkg_image="agentstrator-$pkg_name"
        docker rmi "$pkg_image" 2>/dev/null || true

        if [ -f "$install_script" ]; then
            if AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" "$install_script"; then
                success=$((success + 1))
            else
                failed=$((failed + 1))
                echo "  WARNING: Rebuild failed for $pkg_name"
            fi
        else
            failed=$((failed + 1))
            echo "  WARNING: No install.sh for $pkg_name"
        fi
    done <<< "$installed"

    # Rebuild runtime image from scratch
    echo "Rebuilding runtime image (--no-cache)..."
    "$AGENTSTRATOR_INSTALL_DIR/lib/build-runtime.sh" build --no-cache

    # Rebuild services image
    services_build

    echo ""
    echo "Rebuild complete: $success/$total succeeded, $failed failed."
}
