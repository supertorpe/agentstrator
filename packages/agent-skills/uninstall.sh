#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

# Source commons.sh for helper functions
if [ -f "$AGENTSTRATOR_INSTALL_DIR/commons.sh" ]; then
    source "$AGENTSTRATOR_INSTALL_DIR/commons.sh"
fi

OPENCODE_DIR="$VOLUME/.config/opencode"
SKILLS_DIR="$OPENCODE_DIR/skills"

echo "Removing agent-skills..."

# Remove all skills installed from agent-skills
if [ -d "$SKILLS_DIR" ]; then
    # Remove individual skill directories (20 skills)
    for skill_dir in idea-refine spec-driven-development planning-and-task-breakdown \
        incremental-implementation test-driven-development context-engineering \
        source-driven-development frontend-ui-engineering api-and-interface-design \
        browser-testing-with-devtools debugging-and-error-recovery \
        code-review-and-quality code-simplification security-and-hardening \
        performance-optimization git-workflow-and-versioning ci-cd-and-automation \
        deprecation-and-migration documentation-and-adrs shipping-and-launch \
        using-agent-skills; do
        rm -rf "$SKILLS_DIR/$skill_dir" 2>/dev/null || true
    done

    # Remove agent personas and references
    rm -rf "$SKILLS_DIR/agent-skills-agents" 2>/dev/null || true
    rm -rf "$SKILLS_DIR/agent-skills-references" 2>/dev/null || true
fi

# Remove instructions file
rm -f "$OPENCODE_DIR/agent-skills.md" 2>/dev/null || true
remove_instructions_from_opencode "$VOLUME" "/agentstrator/.config/opencode/agent-skills.md" 2>/dev/null || true

echo "agent-skills uninstalled successfully"
