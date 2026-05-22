#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

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
        /usr/local/bin/ijfw-install
    "

OPENCODE_DIR="$VOLUME/.config/opencode"
SKILLS_DIR="$OPENCODE_DIR/skills"
mkdir -p "$SKILLS_DIR"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "Cloning ijfw repository..."
if git clone --depth 1 https://gitlab.com/therealseandonahoe/ijfw.git "$TMP_DIR/ijfw" 2>/dev/null; then
    # Copy all skills to opencode skills directory
    if [ -d "$TMP_DIR/ijfw/shared/skills" ]; then
        for skill_dir in "$TMP_DIR/ijfw/shared/skills"/*/; do
            skill_name=$(basename "$skill_dir")
            mkdir -p "$SKILLS_DIR/$skill_name"
            if [ -f "$skill_dir/SKILL.md" ]; then
                cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
                echo "  Installed skill: $skill_name"
            fi
        done
    fi

    echo "ijfw installed successfully"
else
    echo "Error: Could not clone ijfw repository"
    exit 1
fi


# # Ensure volume structure
# mkdir -p "$VOLUME/.ijfw/observations"
# mkdir -p "$VOLUME/.config/opencode/skills/ijfw"

# # Register MCP server
# MCP_COMMAND="node /usr/local/lib/node_modules/@ijfw/install/mcp-server/src/server.js"
# add_mcp_to_opencode "$VOLUME" "ijfw-memory" "$MCP_COMMAND"

# # Copy skills (example: cross-audit, design, workflow)
# curl -fsSL "https://gitlab.com/therealseandonahoe/ijfw/-/raw/main/skills/cross-audit.md" \
#     -o "$VOLUME/.config/opencode/skills/ijfw/cross-audit.md" || {
#     echo "Failed to download cross-audit skill. Continuing without it."
# }
# add_instructions_to_opencode "$VOLUME" "/agentstrator/.config/opencode/skills/ijfw/cross-audit.md"

# curl -fsSL "https://gitlab.com/therealseandonahoe/ijfw/-/raw/main/skills/design.md" \
#     -o "$VOLUME/.config/opencode/skills/ijfw/design.md" || {
#     echo "Failed to download design skill. Continuing without it."
# }
# add_instructions_to_opencode "$VOLUME" "/agentstrator/.config/opencode/skills/ijfw/design.md"

# # Set env vars
# env_set "$VOLUME/.env" "IJFW_MCP_PORT" "37890"
# env_set "$VOLUME/.env" "IJFW_LEDGER_DIR" "/agentstrator/.ijfw/observations"

# # Ensure PATH is set (for CLI tools)
# if ! grep -q "IJFW_PATH_ADDED" "$VOLUME/.env"; then
#     echo "PATH=\$PATH:/usr/local/lib/node_modules/@ijfw/install/bin" >> "$VOLUME/.env"
#     echo "IJFW_PATH_ADDED=true" >> "$VOLUME/.env"
# fi