#!/bin/bash
#
# lib/utils.sh — Generic utility functions
# Reusable by any script that sources this file.
#

# ============================================================
# Versioning
# ============================================================

# Compare two version strings.
# Usage: result=$(compare_versions "1.2.3" "1.2.4")
# Returns: "0" if v1 > v2, "1" if v1 < v2, "2" if equal
compare_versions() {
    local v1="$1"
    local v2="$2"

    # Empty versions are treated as equal
    if [ -z "$v1" ] && [ -z "$v2" ]; then
        echo 2
        return
    fi
    if [ -z "$v1" ]; then
        echo 1  # empty is older
        return
    fi
    if [ -z "$v2" ]; then
        echo 0  # non-empty is newer
        return
    fi

    # Split on dots and compare component by component
    local IFS='.'
    read -ra v1_parts <<< "$v1"
    read -ra v2_parts <<< "$v2"

    local max=${#v1_parts[@]}
    if [ ${#v2_parts[@]} -gt $max ]; then
        max=${#v2_parts[@]}
    fi

    for ((i=0; i<max; i++)); do
        local n1=${v1_parts[$i]:-0}
        local n2=${v2_parts[$i]:-0}
        if [ "$n1" -gt "$n2" ] 2>/dev/null; then
            echo 0
            return
        elif [ "$n1" -lt "$n2" ] 2>/dev/null; then
            echo 1
            return
        fi
    done

    echo 2
}

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
