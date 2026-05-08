#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$VOLUME/.cache"
mkdir -p "$VOLUME/.config/opencode/skills"

echo "Creating playwright config with no-sandbox..."
cat > "$VOLUME/.playwright-cli-config.json" << 'CONFIG'
{
  "browser": {
    "launchOptions": {
      "args": ["--no-sandbox", "--disable-setuid-sandbox", "--disable-gpu", "--ignore-certificate-errors", "--allow-insecure-localhost"]
    }
  }
}
CONFIG

mkdir -p "$VOLUME/.config/opencode/skills"

docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    -e "HOME=/agentstrator" \
    -w /agentstrator agentstrator-playwright-cli bash -c "
    export HOME=/agentstrator
    playwright-cli install --skills
    mv .claude/skills/playwright-cli /agentstrator/.config/opencode/skills/
"

echo "playwright-cli installed successfully"
