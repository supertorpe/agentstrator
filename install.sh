#!/bin/sh
set -e

AGENTSTRATOR_INSTALL_BIN="${AGENTSTRATOR_INSTALL_BIN:-$HOME/.local/bin}"
AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
REPO_URL="https://github.com/supertorpe/agentstrator"
TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

echo "Checking prerequisites..."

MISSING=""
for cmd in curl tar jq whiptail; do
    if ! type "$cmd" >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done

if ! type docker >/dev/null 2>&1; then
    MISSING="$MISSING docker"
fi

if ! docker compose version >/dev/null 2>&1; then
    MISSING="$MISSING docker-compose"
fi

if [ -n "$MISSING" ]; then
    echo "ERROR: Missing required commands:$MISSING"
    echo "Please install them and try again."
    exit 1
fi

if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ] || [ -f "$AGENTSTRATOR_INSTALL_BIN/agentstrator" ]; then
    echo "ERROR: agentstrator is already installed."
    echo "To re-run setup, run: agentstrator setup"
    exit 1
fi

echo "Downloading agentstrator..."
curl -fsSL "$REPO_URL/archive/refs/heads/main.tar.gz" | tar xz -C "$TEMP_DIR"

SOURCE_DIR="$TEMP_DIR/agentstrator-main"

mkdir -p "$AGENTSTRATOR_INSTALL_DIR"
mkdir -p "$AGENTSTRATOR_INSTALL_DIR/volume"
mkdir -p "$AGENTSTRATOR_INSTALL_BIN"

cp "$SOURCE_DIR/agentstrator" "$AGENTSTRATOR_INSTALL_BIN/"
cp "$SOURCE_DIR/commons.sh" "$AGENTSTRATOR_INSTALL_DIR/"
cp -r "$SOURCE_DIR/lib" "$AGENTSTRATOR_INSTALL_DIR/"
cp -r "$SOURCE_DIR/core" "$AGENTSTRATOR_INSTALL_DIR/"
cp -r "$SOURCE_DIR/packages" "$AGENTSTRATOR_INSTALL_DIR/"
cp -r "$SOURCE_DIR/services" "$AGENTSTRATOR_INSTALL_DIR/"
cp "$SOURCE_DIR/packages.json" "$AGENTSTRATOR_INSTALL_DIR/" 2>/dev/null || true

chmod +x "$AGENTSTRATOR_INSTALL_BIN/agentstrator"
chmod +x "$AGENTSTRATOR_INSTALL_DIR/commons.sh"

# Save install commit for future upgrade checks
curl -s "https://api.github.com/repos/supertorpe/agentstrator/commits/main" | \
    jq -r '.sha' > "$AGENTSTRATOR_INSTALL_DIR/.install-commit" 2>/dev/null || true

echo "agentstrator installed to $AGENTSTRATOR_INSTALL_DIR"
echo "Running setup..."

exec "$AGENTSTRATOR_INSTALL_BIN/agentstrator" setup
