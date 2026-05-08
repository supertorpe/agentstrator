#!/bin/bash
set -e

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume"

clean_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        return 0
    fi
    find "$dir" -maxdepth 1 -type f \( -name 'nw-*' -o -name 'nw_*' -o -name 'nwbuddy' \) -delete 2>/dev/null || true
}

docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    -e HOME=/agentstrator \
    -e XDG_CONFIG_HOME=/agentstrator/.config \
    -e OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json \
    -e OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode \
    agentstrator-core \
    bash -c "
        export HOME=/agentstrator
        export XDG_CONFIG_HOME=/agentstrator/.config
        export OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json
        export OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode
        source /agentstrator/.local/bin/env
        nwave-ai uninstall --force 2>&1 || echo 'nwave-ai uninstall completed with warnings'
    "

rm -rf "$VOLUME/.nwave" 2>/dev/null || true

rm -f "$VOLUME/.config/opencode/agents/"nw* 2>/dev/null || true
rm -rf "$VOLUME/.config/opencode/skills/"nw* 2>/dev/null || true
find "$VOLUME/.config/opencode" -name ".nwave-agents-manifest.json" -delete 2>/dev/null || true

rm -f "$VOLUME/.config/opencode/plugins/nwave-des.ts" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/.nwave-commands-manifest.json" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/buddy.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/bugfix.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/continue.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/deliver.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/design.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/devops.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/diagram.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/discover.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/discuss.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/distill.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/diverge.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/document.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/execute.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/fast-forward.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/finalize.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/forge.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/hotspot.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/mikado.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/mutation-test.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/new.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/optimize-tests.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/refactor.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/research.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/review.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/rigor.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/roadmap.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/root-why.md" 2>/dev/null || true
rm -f "$VOLUME/.config/opencode/commands/spike.md" 2>/dev/null || true

echo "nwave uninstalled successfully"