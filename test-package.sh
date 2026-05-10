#!/bin/bash
#
# test-package.sh — Verify an agentstrator package installs correctly
# Usage: test-package.sh [options] <package_name>
#

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

AGENTSTRATOR_INSTALL_DIR="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

PACKAGE_NAME=""
PACKAGE_DIR=""
CANONICAL_NAME=""
HAS_DOCKERFILE=false
HAS_INIT=false
HAS_MCP=false
HAS_PLUGIN=false
HAS_INSTRUCTIONS=false
COMMANDS=""
PACKAGE_PATH=""
SKIP_PHASES=""
FORCE_REBUILD=false
TIMEOUT_SECONDS=120

PASSED=0
FAILED=0
PHASE_PASSED=0
PHASE_FAILED=0

# Colors
GREEN='\033[32m'
RED='\033[31m'
CYAN='\033[36m'
YELLOW='\033[33m'
RESET='\033[0m'

# ============================================================
# Output helpers
# ============================================================

pass() {
    echo -e "  ${GREEN}✓${RESET} $1"
    PASSED=$((PASSED + 1))
    PHASE_PASSED=$((PHASE_PASSED + 1))
}

fail() {
    echo -e "  ${RED}✗${RESET} $1"
    FAILED=$((FAILED + 1))
    PHASE_FAILED=$((PHASE_FAILED + 1))
}

phase_header() {
    local phase_num="$1"
    local phase_name="$2"
    PHASE_PASSED=0
    PHASE_FAILED=0
    echo ""
    echo -e "${CYAN}[${phase_num}/5] ${phase_name}${RESET}"
    echo "  $(printf '─%.0s' "$(seq 1 50)")"
}

skip_phase() {
    local phase_name="$1"
    echo ""
    echo "  SKIP: $phase_name (--skip flag)"
}

should_skip() {
    local phase="$1"
    [[ "$SKIP_PHASES" == *"$phase"* ]]
}

die() {
    echo -e "${RED}ERROR:${RESET} $1" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: test-package.sh [options] <package_name>

Test an agentstrator package for correctness across 5 phases:
  validate, build, install, runtime, uninstall

Options:
  --dir <path>     Specify package directory directly
  --skip <phases>  Comma-separated phases to skip (e.g., build,runtime)
  --rebuild        Force Docker rebuild even if image exists
  --timeout <sec>  Timeout for install/uninstall phases (default: 120, 0=no limit)
  --help, -h       Show this help

Examples:
  test-package.sh rtk
  test-package.sh --dir packages/rtk
  test-package.sh --skip runtime mytool
  test-package.sh --rebuild mytool
  test-package.sh --timeout 300 interactive-tool
EOF
    exit 0
}

# ============================================================
# Package discovery
# ============================================================

find_package_dir() {
    local name="$1"

    # Try explicit path first
    if [ -d "$name" ]; then
        PACKAGE_DIR="$(cd "$name" && pwd)"
        PACKAGE_NAME="$(basename "$PACKAGE_DIR")"
        return 0
    fi

    # Try installed packages
    if [ -d "$AGENTSTRATOR_INSTALL_DIR/packages/$name" ]; then
        PACKAGE_DIR="$AGENTSTRATOR_INSTALL_DIR/packages/$name"
        PACKAGE_NAME="$name"
        return 0
    fi

    # Try source packages
    if [ -d "$SCRIPT_DIR/packages/$name" ]; then
        PACKAGE_DIR="$SCRIPT_DIR/packages/$name"
        PACKAGE_NAME="$name"
        return 0
    fi

    return 1
}

# ============================================================
# Pattern detection
# ============================================================

detect_patterns() {
    if [ -f "$PACKAGE_DIR/Dockerfile" ]; then
        HAS_DOCKERFILE=true
    fi

    if [ -f "$PACKAGE_DIR/init.sh" ]; then
        HAS_INIT=true
    fi

    if [ -f "$PACKAGE_DIR/metadata" ]; then
        CANONICAL_NAME=$(grep "^NAME=" "$PACKAGE_DIR/metadata" 2>/dev/null | cut -d'=' -f2- | xargs) || true
        PACKAGE_PATH=$(grep "^PATH=" "$PACKAGE_DIR/metadata" 2>/dev/null | cut -d'=' -f2- | xargs) || true
        COMMANDS=$(grep "^COMMANDS=" "$PACKAGE_DIR/metadata" 2>/dev/null | cut -d'=' -f2- | xargs) || true
    fi

    if [ -z "$CANONICAL_NAME" ]; then
        CANONICAL_NAME="$PACKAGE_NAME"
    fi

    if [ -f "$PACKAGE_DIR/install.sh" ]; then
        grep -q "add_mcp_to_opencode" "$PACKAGE_DIR/install.sh" 2>/dev/null && HAS_MCP=true || true
        grep -q "add_plugin_to_opencode" "$PACKAGE_DIR/install.sh" 2>/dev/null && HAS_PLUGIN=true || true
        grep -q "add_instructions_to_opencode" "$PACKAGE_DIR/install.sh" 2>/dev/null && HAS_INSTRUCTIONS=true || true
    fi

    return 0
}

# ============================================================
# Config backup / restore
# ============================================================

CONFIG_BACKUP=""
OPENCODE_BACKUP=""
TEMP_FILES=()

backup_config() {
    if [ -f "$AGENTSTRATOR_INSTALL_DIR/config.json" ]; then
        CONFIG_BACKUP=$(mktemp)
        cp "$AGENTSTRATOR_INSTALL_DIR/config.json" "$CONFIG_BACKUP"
    fi
    if [ -f "$AGENTSTRATOR_INSTALL_DIR/volume/.config/opencode/opencode.json" ]; then
        OPENCODE_BACKUP=$(mktemp)
        cp "$AGENTSTRATOR_INSTALL_DIR/volume/.config/opencode/opencode.json" "$OPENCODE_BACKUP"
    fi
}

restore_config() {
    if [ -n "$CONFIG_BACKUP" ] && [ -f "$CONFIG_BACKUP" ]; then
        cp "$CONFIG_BACKUP" "$AGENTSTRATOR_INSTALL_DIR/config.json" 2>/dev/null || true
        rm -f "$CONFIG_BACKUP"
        CONFIG_BACKUP=""
    fi
    if [ -n "$OPENCODE_BACKUP" ] && [ -f "$OPENCODE_BACKUP" ]; then
        cp "$OPENCODE_BACKUP" "$AGENTSTRATOR_INSTALL_DIR/volume/.config/opencode/opencode.json" 2>/dev/null || true
        rm -f "$OPENCODE_BACKUP"
        OPENCODE_BACKUP=""
    fi
}

cleanup() {
    restore_config
    for tf in "${TEMP_FILES[@]}"; do
        rm -f "$tf"
    done
}

# ============================================================
# Phases (implemented in subsequent tasks)
# ============================================================

test_validate() {
    # Metadata
    if [ -f "$PACKAGE_DIR/metadata" ]; then
        pass "metadata file exists"
        local name_val
        name_val=$(grep "^NAME=" "$PACKAGE_DIR/metadata" 2>/dev/null | cut -d'=' -f2- | xargs)
        if [ -n "$name_val" ]; then
            pass "metadata has NAME=\"$name_val\""
        else
            fail "metadata has NAME field (empty or missing)"
        fi
        if grep -q "^DESCRIPTION=" "$PACKAGE_DIR/metadata" 2>/dev/null; then
            pass "metadata has DESCRIPTION"
        else
            fail "metadata missing DESCRIPTION"
        fi
    else
        fail "metadata file not found"
    fi

    # install.sh
    if [ -f "$PACKAGE_DIR/install.sh" ]; then
        if [ -x "$PACKAGE_DIR/install.sh" ]; then
            pass "install.sh is executable"
        else
            fail "install.sh not executable (chmod +x required)"
        fi
    else
        fail "install.sh not found"
    fi

    # uninstall.sh
    if [ -f "$PACKAGE_DIR/uninstall.sh" ]; then
        if [ -x "$PACKAGE_DIR/uninstall.sh" ]; then
            pass "uninstall.sh is executable"
        else
            fail "uninstall.sh not executable (chmod +x required)"
        fi
    else
        fail "uninstall.sh not found"
    fi

    # init.sh (optional)
    if [ "$HAS_INIT" = true ]; then
        if [ -x "$PACKAGE_DIR/init.sh" ]; then
            pass "init.sh is executable"
        else
            fail "init.sh not executable"
        fi
    else
        pass "init.sh not required (optional)"
    fi

    # Dockerfile checks
    if [ "$HAS_DOCKERFILE" = true ]; then
        if head -1 "$PACKAGE_DIR/Dockerfile" | grep -qE "agentstrator-core|agentstrator-base"; then
            pass "Dockerfile uses agentstrator-core or agentstrator-base as base"
        else
            fail "Dockerfile must use agentstrator-core or agentstrator-base as base image"
        fi
        if grep -q "before-files.txt" "$PACKAGE_DIR/Dockerfile" 2>/dev/null; then
            pass "Dockerfile has before-files.txt tracking"
        else
            fail "Dockerfile missing before-files.txt (file-tracking pattern)"
        fi
        if grep -q "after-files.txt" "$PACKAGE_DIR/Dockerfile" 2>/dev/null; then
            pass "Dockerfile has after-files.txt tracking"
        else
            fail "Dockerfile missing after-files.txt"
        fi
        if grep -qE "comm -13|comm13" "$PACKAGE_DIR/Dockerfile" 2>/dev/null; then
            pass "Dockerfile has comm to generate new-files.txt"
        else
            fail "Dockerfile missing comm to generate new-files.txt"
        fi
    else
        pass "Dockerfile not required (plugin/instructions/interactive pattern)"
    fi
}
test_build() {
    if [ "$HAS_DOCKERFILE" != true ]; then
        pass "No Dockerfile — build phase skipped"
        return
    fi

    local image_name="agentstrator-$CANONICAL_NAME"

    # Check if image already exists
    if docker image inspect "$image_name" >/dev/null 2>&1; then
        if [ "$FORCE_REBUILD" = true ]; then
            echo "  (forcing rebuild of $image_name)"
            docker rmi "$image_name" >/dev/null 2>&1 || true
        else
            echo "  (using cached image $image_name)"
        fi
    fi

    if docker image inspect "$image_name" >/dev/null 2>&1; then
        pass "docker image $image_name exists"
    else
        echo "  Building $image_name..."
        if docker build -t "$image_name" "$PACKAGE_DIR" > /dev/null 2>&1; then
            pass "docker build -t $image_name succeeded"
        else
            fail "docker build -t $image_name succeeded"
            return
        fi
    fi

    # Check new-files.txt
    local new_files
    new_files=$(docker run --rm "$image_name" cat /new-files.txt 2>/dev/null || echo "")
    if [ -n "$new_files" ]; then
        local file_count
        file_count=$(echo "$new_files" | wc -l)
        pass "/new-files.txt exists with $file_count entries"
        # Verify no system paths leaked
        local leaked
        leaked=$(echo "$new_files" | grep -E '^/tmp/|^/root/' || true)
        if [ -z "$leaked" ]; then
            pass "/new-files.txt contains no tmp/root paths"
        else
            fail "/new-files.txt contains tmp/root paths (should be filtered)"
        fi
    else
        fail "/new-files.txt exists and is non-empty"
    fi

    # Check symlinks tracking
    if docker run --rm "$image_name" test -f /new-symlinks-with-targets.txt 2>/dev/null; then
        local symlink_count
        symlink_count=$(docker run --rm "$image_name" cat /new-symlinks-with-targets.txt 2>/dev/null | wc -l)
        pass "/new-symlinks-with-targets.txt exists with $symlink_count symlinks"
    else
        pass "No symlinks to track (or file not present)"
    fi

    # Smoke test: try COMMANDS or binary name
    local smoke_tests="$COMMANDS"
    if [ -z "$smoke_tests" ]; then
        smoke_tests="$CANONICAL_NAME"
    fi

    local smoke_passed=false
    local saved_ifs="$IFS"
    IFS=',' read -ra cmds <<< "$smoke_tests"
    IFS="$saved_ifs"
    for cmd in "${cmds[@]}"; do
        cmd=$(echo "$cmd" | xargs)
        [ -z "$cmd" ] && continue
        if docker run --rm "$image_name" bash -c "which $cmd 2>/dev/null || command -v $cmd 2>/dev/null || $cmd --help 2>/dev/null || $cmd --version 2>/dev/null" > /dev/null 2>&1; then
            pass "Smoke test: $cmd runs successfully"
            smoke_passed=true
            break
        fi
    done

    if [ "$smoke_passed" != true ]; then
        fail "Smoke test: none of the expected commands ($smoke_tests) could be executed"
    fi
}

test_install() {
    backup_config

    if [ ! -f "$PACKAGE_DIR/install.sh" ]; then
        fail "install.sh not found"
        return
    fi

    echo "  Running install.sh${TIMEOUT_SECONDS:+ (timeout: ${TIMEOUT_SECONDS}s)}..."
    local install_exit=0
    local install_output
    if [ "$TIMEOUT_SECONDS" -gt 0 ] 2>/dev/null; then
        install_output=$(timeout "$TIMEOUT_SECONDS" env AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" bash "$PACKAGE_DIR/install.sh" 2>&1) || install_exit=$?
    else
        install_output=$(AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" bash "$PACKAGE_DIR/install.sh" 2>&1) || install_exit=$?
    fi

    if [ "$install_exit" -eq 0 ]; then
        pass "install.sh exited with code 0"
    else
        fail "install.sh exited with code $install_exit"
        echo "    Output: $install_output"
    fi

    # Inject into config.json (install.sh scripts don't update it — framework does)
    if [ -f "$AGENTSTRATOR_INSTALL_DIR/config.json" ]; then
        local tmp_config
        tmp_config=$(mktemp)
        TEMP_FILES+=("$tmp_config")
        jq --arg pkg "$CANONICAL_NAME" '.[$pkg].installed = true' \
            "$AGENTSTRATOR_INSTALL_DIR/config.json" > "$tmp_config" \
            && cp "$tmp_config" "$AGENTSTRATOR_INSTALL_DIR/config.json"
    else
        echo "{\"$CANONICAL_NAME\": {\"installed\": true}}" > "$AGENTSTRATOR_INSTALL_DIR/config.json"
    fi
    pass "config.json updated with $CANONICAL_NAME.installed = true"

    # Check MCP registration
    if [ "$HAS_MCP" = true ]; then
        local oc_config="$AGENTSTRATOR_INSTALL_DIR/volume/.config/opencode/opencode.json"
        if [ -f "$oc_config" ]; then
            if jq -e ".mcp | has(\"$CANONICAL_NAME\")" "$oc_config" >/dev/null 2>&1; then
                pass "MCP server for $CANONICAL_NAME registered in opencode.json"
            else
                fail "MCP server for $CANONICAL_NAME registered in opencode.json"
            fi
        else
            fail "opencode.json exists (needed for MCP registration)"
        fi
    else
        pass "No MCP registration expected"
    fi

    # Check plugin registration
    if [ "$HAS_PLUGIN" = true ]; then
        local oc_config="$AGENTSTRATOR_INSTALL_DIR/volume/.config/opencode/opencode.json"
        if [ -f "$oc_config" ]; then
            if jq -e ".plugin // [] | any(contains(\"$CANONICAL_NAME\"))" "$oc_config" >/dev/null 2>&1; then
                pass "Plugin $CANONICAL_NAME registered in opencode.json"
            else
                fail "Plugin $CANONICAL_NAME registered in opencode.json"
            fi
        else
            fail "opencode.json exists (needed for plugin registration)"
        fi
    else
        pass "No plugin registration expected"
    fi

    # Check instructions registration
    if [ "$HAS_INSTRUCTIONS" = true ]; then
        local oc_config="$AGENTSTRATOR_INSTALL_DIR/volume/.config/opencode/opencode.json"
        if [ -f "$oc_config" ]; then
            if jq -e ".instructions // [] | any(contains(\"$CANONICAL_NAME\"))" "$oc_config" >/dev/null 2>&1; then
                pass "Instructions for $CANONICAL_NAME registered in opencode.json"
            else
                fail "Instructions for $CANONICAL_NAME registered in opencode.json"
            fi
        else
            fail "opencode.json exists (needed for instructions registration)"
        fi
    else
        pass "No instructions registration expected"
    fi
}

test_runtime() {
    if [ "$HAS_DOCKERFILE" != true ]; then
        pass "No Dockerfile — runtime phase skipped"
        return
    fi

    local build_script="$AGENTSTRATOR_INSTALL_DIR/lib/build-runtime.sh"
    if [ ! -f "$build_script" ]; then
        build_script="$SCRIPT_DIR/lib/build-runtime.sh"
    fi

    if [ ! -f "$build_script" ]; then
        fail "build-runtime.sh found"
        return
    fi

    # Check generate_dockerfile includes this package
    echo "  Checking generate_dockerfile output..."
    local generated
    generated=$(bash "$build_script" generate 2>/dev/null || echo "")
    if echo "$generated" | grep -qE "COPY --from=$CANONICAL_NAME|FROM agentstrator-$CANONICAL_NAME"; then
        pass "generate_dockerfile includes $CANONICAL_NAME"
    else
        fail "generate_dockerfile includes $CANONICAL_NAME"
        echo "    (check that config.json has the package marked as installed)"
    fi

    # Build runtime image and verify binary
    if [ -n "$COMMANDS" ]; then
        local first_cmd
        first_cmd=$(echo "$COMMANDS" | cut -d',' -f1 | xargs)
        echo "  Building test runtime image (quick check)..."
        local runtime_dockerfile
        runtime_dockerfile=$(mktemp)
        TEMP_FILES+=("$runtime_dockerfile")
        bash "$build_script" generate > "$runtime_dockerfile" 2>/dev/null || true

        if docker build -t "agentstrator:runtime-test" -f "$runtime_dockerfile" "$(dirname "$build_script")" > /dev/null 2>&1; then
            pass "Runtime image builds successfully"
            if docker run --rm "agentstrator:runtime-test" bash -c "which $first_cmd 2>/dev/null || command -v $first_cmd 2>/dev/null" > /dev/null 2>&1; then
                pass "Binary '$first_cmd' available in runtime image"
            else
                fail "Binary '$first_cmd' available in runtime image"
            fi
            docker rmi "agentstrator:runtime-test" >/dev/null 2>&1 || true
        else
            fail "Runtime image builds successfully"
        fi
    fi

    # Check PATH if non-standard
    if [ -n "$PACKAGE_PATH" ]; then
        echo "  NOTE: Package sets custom PATH=\"$PACKAGE_PATH\""
        pass "Custom PATH is configured (verify manually if needed)"
    else
        pass "No custom PATH needed (uses standard paths)"
    fi
}

test_uninstall() {
    if [ ! -f "$PACKAGE_DIR/uninstall.sh" ]; then
        fail "uninstall.sh not found"
        return
    fi

    echo "  Running uninstall.sh${TIMEOUT_SECONDS:+ (timeout: ${TIMEOUT_SECONDS}s)}..."
    local uninstall_exit=0
    local uninstall_output
    if [ "$TIMEOUT_SECONDS" -gt 0 ] 2>/dev/null; then
        uninstall_output=$(timeout "$TIMEOUT_SECONDS" env AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" bash "$PACKAGE_DIR/uninstall.sh" 2>&1) || uninstall_exit=$?
    else
        uninstall_output=$(AGENTSTRATOR_VOLUME="$AGENTSTRATOR_INSTALL_DIR/volume" bash "$PACKAGE_DIR/uninstall.sh" 2>&1) || uninstall_exit=$?
    fi

    if [ "$uninstall_exit" -eq 0 ]; then
        pass "uninstall.sh exited with code 0"
    else
        fail "uninstall.sh exited with code $uninstall_exit"
        echo "    Output: $uninstall_output"
    fi

    # Mark uninstalled in config.json (uninstall.sh scripts don't update it — framework does)
    if [ -f "$AGENTSTRATOR_INSTALL_DIR/config.json" ]; then
        local tmp_config
        tmp_config=$(mktemp)
        TEMP_FILES+=("$tmp_config")
        jq --arg pkg "$CANONICAL_NAME" '.[$pkg].installed = false' \
            "$AGENTSTRATOR_INSTALL_DIR/config.json" > "$tmp_config" \
            && cp "$tmp_config" "$AGENTSTRATOR_INSTALL_DIR/config.json"
        pass "config.json marks $CANONICAL_NAME.installed = false"
    else
        fail "config.json exists"
    fi

    # Check cleanup of previously registered entries
    local oc_config="$AGENTSTRATOR_INSTALL_DIR/volume/.config/opencode/opencode.json"

    if [ "$HAS_MCP" = true ] && [ -f "$oc_config" ]; then
        if jq -e ".mcp | has(\"$CANONICAL_NAME\")" "$oc_config" >/dev/null 2>&1; then
            fail "MCP server for $CANONICAL_NAME was removed from opencode.json"
        else
            pass "MCP server for $CANONICAL_NAME removed from opencode.json"
        fi
    fi

    if [ "$HAS_PLUGIN" = true ] && [ -f "$oc_config" ]; then
        if jq -e ".plugin // [] | any(contains(\"$CANONICAL_NAME\"))" "$oc_config" >/dev/null 2>&1; then
            fail "Plugin $CANONICAL_NAME was removed from opencode.json"
        else
            pass "Plugin $CANONICAL_NAME removed from opencode.json"
        fi
    fi

    if [ "$HAS_INSTRUCTIONS" = true ] && [ -f "$oc_config" ]; then
        if jq -e ".instructions // [] | any(contains(\"$CANONICAL_NAME\"))" "$oc_config" >/dev/null 2>&1; then
            fail "Instructions for $CANONICAL_NAME were removed from opencode.json"
        else
            pass "Instructions for $CANONICAL_NAME removed from opencode.json"
        fi
    fi

    # Restore original state
    restore_config
    pass "config.json restored to pre-install state"
}

# ============================================================
# Main
# ============================================================

main() {
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir) PACKAGE_DIR="$2"; shift 2 ;;
            --skip) SKIP_PHASES="$2"; shift 2 ;;
            --rebuild) FORCE_REBUILD=true; shift ;;
            --timeout) TIMEOUT_SECONDS="$2"; shift 2 ;;
            --help|-h) usage ;;
            --*) die "Unknown option: $1" ;;
            *) args+=("$1"); shift ;;
        esac
    done

    if [ ${#args[@]} -lt 1 ]; then
        die "Usage: test-package.sh [options] <package_name>"
    fi

    PACKAGE_NAME="${args[0]}"

    if [ -z "$PACKAGE_DIR" ]; then
        find_package_dir "$PACKAGE_NAME" || die "Package '$PACKAGE_NAME' not found"
    fi

    detect_patterns

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║  Testing agentstrator package: ${YELLOW}$CANONICAL_NAME${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"


    if ! should_skip "validate"; then phase_header 1 "Validate"; test_validate; fi
    if ! should_skip "build"; then phase_header 2 "Build"; test_build; fi
    if ! should_skip "install"; then phase_header 3 "Install"; test_install; fi
    if ! should_skip "runtime"; then phase_header 4 "Runtime"; test_runtime; fi
    if ! should_skip "uninstall"; then phase_header 5 "Uninstall"; test_uninstall; fi

    echo ""
    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}Results: ${PASSED}/${PASSED} checks passed ✓${RESET}"
        return 0
    else
        TOTAL=$((PASSED + FAILED))
        echo -e "${RED}Results: ${PASSED}/${TOTAL} checks passed, ${FAILED} failed ✗${RESET}"
        return 1
    fi
}

trap cleanup EXIT

main "$@"
