#!/bin/bash
#
# lib/upgrade.sh — Agentstrator upgrade functions
#

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
AGENTSTRATOR_INSTALL_BIN="${AGENTSTRATOR_INSTALL_BIN:-$HOME/.local/bin}"
INSTALL_COMMIT_FILE="$AGENTSTRATOR_INSTALL_DIR/.install-commit"
REPO_URL="https://github.com/supertorpe/agentstrator"

# Check if a newer commit exists on GitHub
# Returns: "0" if up to date, "1" if upgrade available
check_upgrade() {
    if [ ! -f "$INSTALL_COMMIT_FILE" ]; then
        echo "1"  # No record = assume upgrade needed
        return
    fi

    local current_commit
    current_commit=$(cat "$INSTALL_COMMIT_FILE" 2>/dev/null | tr -d '\n')

    if [ -z "$current_commit" ]; then
        echo "1"
        return
    fi

    local latest_commit
    latest_commit=$(curl -s "https://api.github.com/repos/supertorpe/agentstrator/commits/main" | \
        jq -r '.sha' 2>/dev/null)

    if [ -z "$latest_commit" ]; then
        echo "0"  # Can't check, assume up to date
        return
    fi

    if [ "$current_commit" = "$latest_commit" ]; then
        echo "0"  # Up to date
    else
        echo "1"  # Upgrade available
    fi
}

# Upgrade agentstrator: check GitHub for new commit, download and rebuild
upgrade() {
    echo "Checking for agentstrator updates..."

    local upgrade_available
    upgrade_available=$(check_upgrade)

    if [ "$upgrade_available" = "0" ]; then
        echo "agentstrator is already up to date."
        return 0
    fi

    echo "New version available. Upgrading..."

    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    # Download latest version
    echo "Downloading latest agentstrator..."
    if ! curl -fsSL "$REPO_URL/archive/refs/heads/main.tar.gz" | tar xz -C "$TEMP_DIR"; then
        echo "ERROR: Failed to download agentstrator"
        return 1
    fi

    local SOURCE_DIR="$TEMP_DIR/agentstrator-main"

    # Update core files
    echo "Updating agentstrator files..."
    if [ -f "$SOURCE_DIR/agentstrator" ]; then
        cp "$SOURCE_DIR/agentstrator" "$AGENTSTRATOR_INSTALL_BIN/" 2>/dev/null || true
        chmod +x "$AGENTSTRATOR_INSTALL_BIN/agentstrator" 2>/dev/null || true
    fi

    if [ -f "$SOURCE_DIR/commons.sh" ]; then
        cp "$SOURCE_DIR/commons.sh" "$AGENTSTRATOR_INSTALL_DIR/" 2>/dev/null || true
        chmod +x "$AGENTSTRATOR_INSTALL_DIR/commons.sh" 2>/dev/null || true
    fi

    # Update packages
    if [ -d "$SOURCE_DIR/packages" ]; then
        cp -r "$SOURCE_DIR/packages" "$AGENTSTRATOR_INSTALL_DIR/" 2>/dev/null || true
    fi

    # Update services
    if [ -d "$SOURCE_DIR/services" ]; then
        cp -r "$SOURCE_DIR/services" "$AGENTSTRATOR_INSTALL_DIR/" 2>/dev/null || true
    fi

    # Update lib
    if [ -d "$SOURCE_DIR/lib" ]; then
        cp -r "$SOURCE_DIR/lib" "$AGENTSTRATOR_INSTALL_DIR/" 2>/dev/null || true
    fi

    # Update packages.json
    if [ -f "$SOURCE_DIR/packages.json" ]; then
        cp "$SOURCE_DIR/packages.json" "$AGENTSTRATOR_INSTALL_DIR/" 2>/dev/null || true
    fi

    # Update core
    if [ -d "$SOURCE_DIR/core" ]; then
        cp -r "$SOURCE_DIR/core" "$AGENTSTRATOR_INSTALL_DIR/" 2>/dev/null || true
    fi

    # Save new commit hash
    local new_commit
    new_commit=$(curl -s "https://api.github.com/repos/supertorpe/agentstrator/commits/main" | \
        jq -r '.sha' 2>/dev/null)
    if [ -n "$new_commit" ]; then
        echo "$new_commit" > "$INSTALL_COMMIT_FILE"
    fi

    # Ask user if they want to rebuild now
    echo ""
    if [[ -t 0 ]]; then
        read -p "New version downloaded. Rebuild images now? [Y/n] " -n 1 -r reply
        echo ""
        if [[ "$reply" =~ ^[Yy]$ ]] || [[ -z "$reply" ]]; then
            echo "Rebuilding runtime image (--no-cache)..."
            "$AGENTSTRATOR_INSTALL_DIR/lib/build-runtime.sh" build --no-cache
        else
            echo "Skipping rebuild. You can rebuild later with 'agentstrator rebuild'."
        fi
    else
        echo "Not a terminal. Skipping rebuild. Run 'agentstrator rebuild' to rebuild images."
    fi

    echo ""
    echo "agentstrator upgraded successfully."
    echo "Please restart any running agentstrator sessions."
}

# Show current and latest version info
upgrade_status() {
    local current_commit=""
    local latest_commit=""

    if [ -f "$INSTALL_COMMIT_FILE" ]; then
        current_commit=$(cat "$INSTALL_COMMIT_FILE" 2>/dev/null | head -c 7)
    fi

    latest_commit=$(curl -s "https://api.github.com/repos/supertorpe/agentstrator/commits/main" | \
        jq -r '.sha' 2>/dev/null | head -c 7)

    echo "Current commit: ${current_commit:-unknown}"
    echo "Latest commit:  ${latest_commit:-unknown}"

    if [ "$current_commit" = "$latest_commit" ] && [ -n "$current_commit" ]; then
        echo "Status: Up to date"
    else
        echo "Status: Upgrade available"
    fi
}
