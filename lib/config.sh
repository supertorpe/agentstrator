#!/bin/bash
#
# lib/config.sh — JSON config file management
# Depends on: CONFIG_FILE (set by caller)
#

# Read a JSON config file, returning "{}" if missing or empty.
# Usage: config=$(get_config)
get_config() {
    if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo "{}"
    fi
}

# Write JSON config.
# Usage: write_config "$json_content"
write_config() {
    echo "$1" > "$CONFIG_FILE"
}
