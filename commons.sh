#!/bin/bash
#
# commons.sh - Shared functions for component install/uninstall scripts
#

# ============================================================
# Config Management
# ============================================================

# Prompt to copy a host config file into the volume (only if host file exists
# and volume file does not already exist).
# Usage: prompt_copy_config <host_path> <volume_path>
prompt_copy_config() {
    local host_config="$1"
    local volume_config="$2"

    if [ -f "$host_config" ] && [ ! -f "$volume_config" ]; then
        local tty
        tty="$(get_tty)"
        echo ""
        echo "Detected configuration at $host_config"
        if [ -n "$tty" ] && [ -r "$tty" ]; then
            echo -n "Do you want to copy this configuration into the volume? [Y/n] "
            read -r answer < "$tty"
            answer="${answer:-y}"
        else
            answer="y"
        fi
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            local volume_config_dir
            volume_config_dir="$(dirname "$volume_config")"
            mkdir -p "$volume_config_dir"
            cp "$host_config" "$volume_config"
            echo "Configuration copied to $volume_config_dir/"
        fi
    fi
}

# Set or update a key in a .env-style file.
# Usage: env_set <file> <key> <value>
env_set() {
    local file="$1" key="$2" value="$3"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        # Use awk to avoid sed delimiter issues with special chars in value
        awk -v k="$key" -v v="$value" 'BEGIN{FS=OFS="="} $1==k{$0=k"="v}1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    elif [ -n "$value" ]; then
        echo "${key}=${value}" >> "$file"
    fi
}

# Remove a key from a .env-style file.
# Usage: env_remove <file> <key>
env_remove() {
    local file="$1" key="$2"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        grep -v "^${key}=" "$file" > "$file.tmp" 2>/dev/null && mv "$file.tmp" "$file" || true
    fi
}

# ============================================================
# TTY / Interactive Input
# ============================================================

# Detect if a terminal is available for interactive input.
# Usage: TTY="$(get_tty)"
# Returns: "/dev/tty" if available, empty string otherwise
# Checks /dev/tty directly (works even when stdin/stdout are redirected
# by a TUI menu or piping).
get_tty() {
    if [ -c /dev/tty ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
        echo "/dev/tty"
    elif [ -c /dev/pts/0 ] && [ -w /dev/pts/0 ]; then
        for tty in /dev/pts/[0-9]*; do
            [ -c "$tty" ] && [ -r "$tty" ] && echo "$tty" && return 0
        done
    fi
}

# ============================================================
# Docker Infrastructure
# ============================================================

# Ensure the agentstrator Docker network exists.
ensure_network() {
    if ! docker network inspect agentstrator-net &>/dev/null; then
        echo "Creating Docker network 'agentstrator-net'..."
        docker network create agentstrator-net
    fi
}

# Check if the registry service is installed and running.
# Returns 0 if registry is installed, 1 otherwise.
# Uses: AGENTSTRATOR_INSTALL_DIR (must be set by caller)
registry_installed() {
    local config_dir="${AGENTSTRATOR_INSTALL_DIR:-$HOME/.agentstrator}"
    [ -f "$config_dir/services/docker-compose.registry.yml" ] && return 0 || return 1
}

# ============================================================
# OpenCode JSON Manipulation
# ============================================================

# Internal helper: runs a Node.js script against opencode config file.
# The script receives the config object as variable `c` and should mutate it.
# The result is written back to the file.
# Usage: _patch_opencode <config_dir> <node_script> [config_filename]
# Default config_filename is "opencode.json"
_patch_opencode() {
    local config_dir="$1"
    local node_script="$2"
    local config_file="${3:-opencode.json}"

    if [ ! -f "$config_dir/$config_file" ]; then
        return 0
    fi

    docker run --rm -v "$config_dir:/tmp/oc" node:22-slim node -e "
const fs = require('fs');
const p = '/tmp/oc/$config_file';
let c = {};
try { c = JSON.parse(fs.readFileSync(p, 'utf8')); } catch(e) {}
${node_script}
fs.writeFileSync(p, JSON.stringify(c, null, 2) + '\n');
"
}

# Add an MCP server entry to opencode.json.
# Usage: add_mcp_to_opencode <volume> <name> <command_json_string>
# Example: add_mcp_to_opencode "$VOLUME" "mytool" '{"type":"local","command":["/agentstrator/mytool-mcp"],"enabled":true}'
add_mcp_to_opencode() {
    local volume="$1" name="$2" cmd_json="$3"
    local config_dir="$volume/.config/opencode"
    mkdir -p "$config_dir"

    _patch_opencode "$config_dir" "
if (!c.mcp) c.mcp = {};
if (!c.mcp['$name']) {
    c.mcp['$name'] = JSON.parse('$cmd_json');
    console.log('MCP server $name added');
} else {
    console.log('MCP server $name already configured');
}
"
}

# Remove an MCP server entry from opencode.json.
# Usage: remove_mcp_from_opencode <volume> <name>
remove_mcp_from_opencode() {
    local volume="$1" name="$2"
    local config_dir="$volume/.config/opencode"

    _patch_opencode "$config_dir" "
if (c.mcp && c.mcp['$name']) {
    delete c.mcp['$name'];
    if (Object.keys(c.mcp).length === 0) delete c.mcp;
    console.log('MCP server $name removed');
} else {
    console.log('MCP server $name not found');
}
"
}

# Add a plugin reference to opencode.json.
# Usage: add_plugin_to_opencode <volume> <plugin_ref>
# Example: add_plugin_to_opencode "$VOLUME" "mytool@git+https://github.com/example/mytool.git"
add_plugin_to_opencode() {
    local volume="$1" plugin_ref="$2"
    local config_dir="$volume/.config/opencode"
    mkdir -p "$config_dir"

    _patch_opencode "$config_dir" "
if (!c.plugin) c.plugin = [];
if (!c.plugin.includes('$plugin_ref')) {
    c.plugin.push('$plugin_ref');
    console.log('Plugin $plugin_ref added');
} else {
    console.log('Plugin $plugin_ref already exists');
}
"
}

# Remove a plugin reference from opencode.json.
# Usage: remove_plugin_from_opencode <volume> <plugin_ref>
remove_plugin_from_opencode() {
    local volume="$1" plugin_ref="$2"
    local config_dir="$volume/.config/opencode"

    _patch_opencode "$config_dir" "
if (c.plugin) {
    const idx = c.plugin.indexOf('$plugin_ref');
    if (idx !== -1) {
        c.plugin.splice(idx, 1);
        console.log('Plugin $plugin_ref removed');
    } else {
        console.log('Plugin $plugin_ref not found');
    }
    if (c.plugin.length === 0) delete c.plugin;
} else {
    console.log('No plugins to remove');
}
"
}

# Add one or more instruction files to opencode config file.
# Usage: add_instructions_to_opencode <volume> <instruction> [<instruction>...]
# Usage: add_instructions_to_opencode <volume> <config_file> <instruction> [<instruction>...]
# Examples:
#   add_instructions_to_opencode "$VOLUME" "my-instruction.md"
#   add_instructions_to_opencode "$VOLUME" "my-config.json" "my-instruction.md"
add_instructions_to_opencode() {
    local volume="$1"
    local config_file="opencode.json"
    shift

    # If next arg ends with .json, treat it as config filename
    if [[ "$1" == *.json ]]; then
        config_file="$1"
        shift
    fi

    local config_dir="$volume/.config/opencode"
    mkdir -p "$config_dir"

    local items_json="["
    local first=1
    for item in "$@"; do
        [ "$first" -eq 0 ] && items_json+=","
        items_json+="\"$item\""
        first=0
    done
    items_json+="]"

    _patch_opencode "$config_dir" "
if (!c.instructions) c.instructions = [];
const newItems = $items_json;
newItems.forEach(item => {
    if (!c.instructions.includes(item)) {
        c.instructions.push(item);
        console.log('Instruction ' + item + ' added to $config_file');
    } else {
        console.log('Instruction ' + item + ' already exists in $config_file');
    }
});
" "$config_file"
}

# Remove an instruction file from opencode.json.
# Usage: remove_instructions_from_opencode <volume> <instruction>
remove_instructions_from_opencode() {
    local volume="$1" instruction="$2"
    local config_dir="$volume/.config/opencode"

    _patch_opencode "$config_dir" "
if (c.instructions) {
    const idx = c.instructions.indexOf('$instruction');
    if (idx !== -1) {
        c.instructions.splice(idx, 1);
        console.log('Instruction $instruction removed');
    } else {
        console.log('Instruction $instruction not found');
    }
    if (c.instructions.length === 0) delete c.instructions;
} else {
    console.log('No instructions to remove');
}
"
}

# Generate dev container instruction file for the agent.
# Usage: generate_dev_container_instructions <volume> <dev_container> <package_commands> <instruction_filename> <config_file>
generate_dev_container_instructions() {
    local volume="$1" dev_container="$2" package_commands="$3"
    local instruction_filename="${4:-dev-container.md}"
    local config_file="${5:-opencode.json}"
    local config_dir="$volume/.config/opencode"
    mkdir -p "$config_dir"

    local instruction_file="$config_dir/$instruction_filename"

    # Build the package commands list
    local pkg_list
    pkg_list=$(echo "$package_commands" | tr ',' '\n' | grep -v '^$' | while read -r cmd; do
        echo "- \`$cmd\`"
    done)

    cat > "$instruction_file" << EOF
### 1. System Architecture
-   **Location:** You are running in a **Sidecar Container**.
-   **Dev container** The main development container is \`$dev_container\`
-   **File Access:** You have mounted the same volumes as the development container, so you have  direct access to the project's files and use "edit", "write", "read", "grep", "glob" and "apply_patch" tools.
-   **Runtime Isolation:** However this container **does not** have the project dependencies (Python, Node, etc.) installed. It only contains your core tools: $pkg_list.

### 2. Execution Strategy

1.  **Direct execution:** You must execute any of the core tools ($pkg_list) directly.
2.  **Delegated execution:** To run the code or tests, you **must** bridge to the **Development Container**:
   \`\`\`bash
   docker exec $dev_container <command>
   \`\`\`
3.  **State:** Remember that while you see the files changing, the processes happen in the sibling container. Always check docker ps if a command fails to ensure the $dev_container is reachable.
EOF

    add_instructions_to_opencode "$volume" "$config_file" "/agentstrator/.config/opencode/$instruction_filename" 2>/dev/null || true
}

# Inject a permission into an opencode config file.
# Usage: add_permission_to_opencode <volume> <config_file> <permission> <value>
# Example: add_permission_to_opencode "$VOLUME" "opencode-server.json" "question" "deny"
add_permission_to_opencode() {
    local volume="$1" config_file="$2" permission="$3" value="$4"
    local config_dir="$volume/.config/opencode"

    docker run --rm -v "$config_dir:/tmp/oc" node:22-slim node -e "
const fs = require('fs');
const p = '/tmp/oc/$config_file';
let c = {};
try { c = JSON.parse(fs.readFileSync(p, 'utf8')); } catch(e) {}
if (!c.permission) c.permission = {};
c.permission.$permission = '$value';
fs.writeFileSync(p, JSON.stringify(c, null, 2) + '\n');
console.log('permission.$permission set to $value');
"
}
