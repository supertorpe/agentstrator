#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

mkdir -p "$VOLUME/.config/opencode"

CAVEMAN_MD="$VOLUME/.config/opencode/caveman.md"
CAVEMAN_URL="https://github.com/JuliusBrussee/caveman/raw/refs/heads/main/caveman/SKILL.md"

if [ -f "$CAVEMAN_MD" ]; then
    if grep -q "Caveman Mode" "$CAVEMAN_MD" 2>/dev/null; then
        echo "Caveman mode already installed"
    else
        echo "Adding caveman mode to caveman.md..."
        curl -fsSL "$CAVEMAN_URL" >> "$CAVEMAN_MD"
    fi
else
    echo "Creating caveman.md..."
    curl -fsSL "$CAVEMAN_URL" > "$CAVEMAN_MD"
fi

add_instructions_to_opencode "$VOLUME" "/agentstrator/.config/opencode/caveman.md" 2>/dev/null || true

echo "caveman installed successfully"