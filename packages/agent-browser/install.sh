#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Creating agent-browser config with no-sandbox..."
mkdir -p "$VOLUME/.config/agent-browser"
cat > "$VOLUME/.config/agent-browser/config.json" << 'CONFIG'
{
  "headed": false,
  "args": ["--no-sandbox", "--disable-setuid-sandbox", "--disable-gpu", "--ignore-certificate-errors", "--allow-insecure-localhost"]
}
CONFIG

mkdir -p "$VOLUME/.config/opencode/skills"

docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    -e "HOME=/agentstrator" \
    -w /agentstrator agentstrator-agent-browser bash -c "
    export HOME=/agentstrator
    agent-browser install --with-deps
    cp -r /usr/local/lib/node_modules/agent-browser/skill-data/* /agentstrator/.config/opencode/skills/
"

echo "agent-browser installed successfully"
