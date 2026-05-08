#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
CONFIG_DIR="$AGENTSTRATOR_INSTALL_DIR"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

OPENCODE_DIR="$VOLUME/.config/opencode"
SKILLS_DIR="$OPENCODE_DIR/skills"
mkdir -p "$SKILLS_DIR/using-leankg"

# Register MCP server
add_mcp_to_opencode "$VOLUME" "leankg" \
    '{"type": "local", "command": ["leankg", "mcp-stdio", "--watch"], "enabled": true}'

# Register plugin
add_plugin_to_opencode "$VOLUME" "leankg@git+https://github.com/FreePeak/LeanKG.git"

# Install OpenCode skill
SKILL_URL="https://raw.githubusercontent.com/FreePeak/LeanKG/main/.opencode/skills/using-leankg/SKILL.md"
if curl -fsSL "$SKILL_URL" > "$SKILLS_DIR/using-leankg/SKILL.md" 2>/dev/null; then
    echo "LeanKG skill installed"
else
    echo "Warning: Could not download LeanKG skill"
fi

# Install AGENTS.md instructions
AGENTS_URL="https://raw.githubusercontent.com/FreePeak/LeanKG/main/instructions/leankg-tools.md"
AGENTS_FILE="$OPENCODE_DIR/AGENTS.md"
if curl -fsSL "$AGENTS_URL" >> "$AGENTS_FILE" 2>/dev/null; then
    echo "LeanKG instructions added to AGENTS.md"
else
    echo "Warning: Could not download LeanKG instructions"
fi

echo "leankg installed successfully"