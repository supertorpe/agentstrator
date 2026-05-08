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

OPENCODE_DIR="$VOLUME/.config/opencode"
SKILLS_DIR="$OPENCODE_DIR/skills"
mkdir -p "$SKILLS_DIR"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "Cloning agent-skills repository..."
if git clone --depth 1 https://github.com/addyosmani/agent-skills.git "$TMP_DIR/agent-skills" 2>/dev/null; then
    # Copy all skills to opencode skills directory
    if [ -d "$TMP_DIR/agent-skills/skills" ]; then
        for skill_dir in "$TMP_DIR/agent-skills/skills"/*/; do
            skill_name=$(basename "$skill_dir")
            mkdir -p "$SKILLS_DIR/$skill_name"
            if [ -f "$skill_dir/SKILL.md" ]; then
                cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
                echo "  Installed skill: $skill_name"
            fi
        done
    fi

    # Copy AGENTS.md as instructions for opencode
    if [ -f "$TMP_DIR/agent-skills/AGENTS.md" ]; then
        cp "$TMP_DIR/agent-skills/AGENTS.md" "$OPENCODE_DIR/agent-skills.md"
        add_instructions_to_opencode "$VOLUME" "/agentstrator/.config/opencode/agent-skills.md" 2>/dev/null || true
        echo "  Added agent-skills instructions to opencode"
    fi

    # Copy agents to skills directory (agent personas)
    if [ -d "$TMP_DIR/agent-skills/agents" ]; then
        mkdir -p "$SKILLS_DIR/agent-skills-agents"
        cp "$TMP_DIR/agent-skills/agents"/*.md "$SKILLS_DIR/agent-skills-agents/" 2>/dev/null || true
        echo "  Installed agent personas"
    fi

    # Copy references to skills directory
    if [ -d "$TMP_DIR/agent-skills/references" ]; then
        mkdir -p "$SKILLS_DIR/agent-skills-references"
        cp "$TMP_DIR/agent-skills/references"/*.md "$SKILLS_DIR/agent-skills-references/" 2>/dev/null || true
        echo "  Installed reference checklists"
    fi

    echo "agent-skills installed successfully"
else
    echo "Error: Could not clone agent-skills repository"
    exit 1
fi
