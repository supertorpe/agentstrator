#!/bin/bash
#
# lib/utils.sh — Generic utility functions
# Reusable by any script that sources this file.
#

# ============================================================
# Network
# ============================================================

# Find a free TCP port in a given range.
# Usage: port=$(find_free_port 8080 1000)
find_free_port() {
    local start_port=${1:-8080}
    local range=${2:-1000}
    local end_port=$((start_port + range))
    local port=$start_port
    while [[ $port -le $end_port ]]; do
        if ! nc -z localhost "$port" 2>/dev/null; then
            echo "$port"
            return 0
        fi
        ((port++))
    done
    echo "ERROR: No free port found in range ${start_port}-${end_port}" >&2
    return 1
}


# ============================================================
# String Utilities
# ============================================================

# Sanitize a string to be a safe hostname/identifier.
# Usage: safe=$(sanitize_name "my workspace name!")
sanitize_name() {
    local name="$1"
    echo "$name" | tr '[:space:]' '-' | tr -cd '[:alnum:]-' | sed 's/^-//;s/-$//'
}

# Base64 of the hash of a string.
# Usage: encoded=$(hash_base64 "my workspace name!")
hash_base64() {
    local input="$1"
    echo -n "$input" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='
}

# Build a colon-separated path string from a colon-separated input.
# Usage: result=$(build_path_str "/a:/b:/c")
build_path_str() {
    local input="$1"
    local result=""
    for p in $(echo "$input" | tr ':' ' '); do
        if [ -n "$p" ]; then
            result="${result}:${p}"
        fi
    done
    echo "$result"
}
