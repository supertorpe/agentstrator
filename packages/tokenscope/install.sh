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

add_plugin_to_opencode "$VOLUME" "@ramtinj95/opencode-tokenscope" 2>/dev/null || true

COMMAND_DIR="$VOLUME/.config/opencode/command"
mkdir -p "$COMMAND_DIR"

if [ ! -f "$COMMAND_DIR/tokenscope.md" ]; then
    echo "Creating tokenscope command..."
    cat > "$COMMAND_DIR/tokenscope.md" << 'COMMAND'
---
description: Analyze token usage across the current session with detailed breakdowns by category
---

Call the tokenscope tool directly without delegating to other agents.
Leave sessionID unset unless the user explicitly asked to analyze a different session.
Then cat the token-usage-output.txt. DONT DO ANYTHING ELSE WITH THE OUTPUT.
COMMAND
fi

echo "tokenscope installed successfully. Restart OpenCode and run /tokenscope"
