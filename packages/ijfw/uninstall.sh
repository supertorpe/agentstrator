#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"
OPENCODE_DIR="$VOLUME/.config/opencode"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

docker run --rm -it \
    -v "$VOLUME:/agentstrator" \
    -u $(id -u):$(id -g) \
    -e HOME=/agentstrator \
    -e OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json \
    -e OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode \
    --entrypoint bash agentstrator-ijfw -c "
        export HOME=/agentstrator
        export OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json
        export OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode
        /usr/local/bin/ijfw uninstall --purge
    "

# # Remove MCP server
remove_mcp_from_opencode "$VOLUME" "ijfw-memory"

# # Remove skills
find $VOLUME/.config/opencode/skills -maxdepth 1 -type d -name 'ijfw-*' -exec rm -rf {} +

# remove_instructions_from_opencode "$VOLUME" "/agentstrator/.config/opencode/skills/ijfw/cross-audit.md"
# remove_instructions_from_opencode "$VOLUME" "/agentstrator/.config/opencode/skills/ijfw/design.md"

# # Remove env vars
# env_remove "$VOLUME/.env" "IJFW_MCP_PORT"
# env_remove "$VOLUME/.env" "IJFW_LEDGER_DIR"

# # Remove PATH entry
# sed -i '/IJFW_PATH_ADDED/d' "$VOLUME/.env"
# sed -i '/PATH=\$PATH:\/usr\/local\/lib\/node_modules\/@ijfw\/install\/bin/d' "$VOLUME/.env"