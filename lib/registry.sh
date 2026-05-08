#!/bin/bash
#
# lib/registry.sh — Registry operations
# Depends on: REGISTRY_URL (set by caller), jq, curl
#

# Register an agent with the registry.
# Usage: register_with_registry "$name" "$url" ["$registry_url"]
register_with_registry() {
    local name="$1"
    local url="$2"
    local registry_url="${3:-$REGISTRY_URL}"

    echo "Registering $name at $url with registry..."

    if [[ "$registry_url" == file://* ]]; then
        _register_file "$name" "$url" "$registry_url"
    else
        _register_http "$name" "$url" "$registry_url"
    fi
}

# Internal: register with file-based registry with retries.
# Usage: _register_file "$name" "$url" "$registry_url"
_register_file() {
    local name="$1"
    local url="$2"
    local registry_url="$3"
    local file_path="${registry_url#file://}"

    for i in 1 2 3 4 5; do
        if _update_registry_json "$file_path" "$name" "$url" "add"; then
            echo "Registered successfully as $name"
            return 0
        fi
        echo "Registration attempt $i failed, retrying in $((i * 2))s..."
        sleep $((i * 2))
    done

    echo "ERROR: Failed to register after 5 attempts"
    return 1
}

# Internal: basic heuristic check if file looks like valid agents JSON (jq/python3 fallback).
_looks_like_agents_json() {
    local file="$1"
    [[ -s "$file" ]] || return 1
    grep -q '"agents"' "$file" 2>/dev/null || return 1
    head -c1 "$file" | grep -q '{' 2>/dev/null || return 1
    tail -c1 "$file" | grep -q '}' 2>/dev/null || return 1
    return 0
}

# Internal: update registry JSON file (add, remove, or heartbeat).
# Tries jq first, falls back to python3 if unavailable.
# Usage: _update_registry_json "$file" "$name" "$url" "add|remove|heartbeat"
_update_registry_json() {
    local file="$1"
    local name="$2"
    local url="$3"
    local action="$4"

    if [[ ! -f "$file" ]]; then
        echo '{"agents": []}' > "$file" 2>/dev/null || return 1
    elif [[ ! -s "$file" ]]; then
        echo '{"agents": []}' > "$file" 2>/dev/null || return 1
    elif command -v jq >/dev/null 2>&1 && jq empty "$file" 2>/dev/null; then
        : # valid JSON
    elif command -v python3 >/dev/null 2>&1 && python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
        : # valid JSON
    elif ! _looks_like_agents_json "$file"; then
        echo '{"agents": []}' > "$file" 2>/dev/null || return 1
    fi

    if [[ "$action" == "add" ]]; then
        local now
        now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        if command -v jq >/dev/null 2>&1; then
            local agents
            agents=$(jq --arg name "$name" --arg url "$url" --arg now "$now" \
                '.agents | map(select(.name != $name)) + [{"name": $name, "url": $url, "registered_at": $now, "last_heartbeat": $now}]' \
                "$file" 2>/dev/null) || return 1
            [[ -z "$agents" ]] && return 1
            echo "{\"agents\": $agents}" > "$file"
            return 0
        fi

        if command -v python3 >/dev/null 2>&1; then
            NAME="$name" URL="$url" NOW="$now" FILE="$file" python3 -c '
import json, os
f = os.environ["FILE"]
with open(f) as fh:
    data = json.load(fh)
name = os.environ["NAME"]
data["agents"] = [a for a in data["agents"] if a["name"] != name]
data["agents"].append({"name": name, "url": os.environ["URL"], "registered_at": os.environ["NOW"], "last_heartbeat": os.environ["NOW"]})
with open(f, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
' 2>/dev/null || return 1
            return 0
        fi

        return 1
    elif [[ "$action" == "remove" ]]; then
        if command -v jq &>/dev/null; then
            local agents
            agents=$(jq --arg name "$name" '.agents | map(select(.name != $name))' "$file" 2>/dev/null) || return 1
            echo "{\"agents\": $agents}" > "$file"
            return 0
        fi

        if command -v python3 >/dev/null 2>&1; then
            NAME="$name" FILE="$file" python3 -c '
import json, os
f = os.environ["FILE"]
with open(f) as fh:
    data = json.load(fh)
data["agents"] = [a for a in data["agents"] if a["name"] != os.environ["NAME"]]
with open(f, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
' 2>/dev/null || return 1
            return 0
        fi

        return 1
    elif [[ "$action" == "heartbeat" ]]; then
        local now
        now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        if command -v jq &>/dev/null; then
            local agents
            agents=$(jq --arg name "$name" --arg now "$now" \
                '.agents | map(if .name == $name then .last_heartbeat = $now else . end)' "$file" 2>/dev/null) || return 1
            echo "{\"agents\": $agents}" > "$file"
            return 0
        fi

        if command -v python3 >/dev/null 2>&1; then
            NAME="$name" NOW="$now" FILE="$file" python3 -c '
import json, os
f = os.environ["FILE"]
with open(f) as fh:
    data = json.load(fh)
name = os.environ["NAME"]
now = os.environ["NOW"]
for a in data["agents"]:
    if a["name"] == name:
        a["last_heartbeat"] = now
with open(f, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
' 2>/dev/null || return 1
            return 0
        fi

        return 1
    fi

    return 1
}

# Internal: register with HTTP registry with retries.
# Usage: _register_http "$name" "$url" "$registry_url"
_register_http() {
    local name="$1"
    local url="$2"
    local registry_url="$3"

    local payload="{\"name\":\"$name\",\"url\":\"$url\"}"

    for i in 1 2 3 4 5; do
        if curl -s -X POST "$registry_url/register" \
            -H "Content-Type: application/json" \
            -d "$payload" > /dev/null 2>&1; then
            echo "Registered successfully as $name"
            return 0
        fi
        echo "Registration attempt $i failed, retrying in $((i * 2))s..."
        sleep $((i * 2))
    done

    echo "ERROR: Failed to register after 5 attempts"
    return 1
}

# Deregister an agent from the registry.
# Usage: deregister_from_registry "$name" ["$registry_url"]
deregister_from_registry() {
    local name="$1"
    local registry_url="${2:-$REGISTRY_URL}"

    if [[ "$registry_url" == file://* ]]; then
        local file_path="${registry_url#file://}"
        if _update_registry_json "$file_path" "$name" "" "remove"; then
            echo "Deregistered from registry"
        else
            echo "Failed to deregister from registry"
        fi
    else
        if curl -s -X POST "$registry_url/deregister" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$name\"}" > /dev/null 2>&1; then
            echo "Deregistered from registry"
        else
            echo "Failed to deregister from registry"
        fi
    fi
}

# Send periodic heartbeat to the registry (runs in background).
# Usage: send_heartbeat "$name" ["$registry_url"]
send_heartbeat() {
    local name="$1"
    local registry_url="${2:-$REGISTRY_URL}"

    while true; do
        sleep 30
        if [[ "$registry_url" == file://* ]]; then
            local file_path="${registry_url#file://}"
            _update_registry_json "$file_path" "$name" "" "heartbeat" > /dev/null 2>&1 || true
        else
            curl -s -X POST "$registry_url/heartbeat" \
                -H "Content-Type: application/json" \
                -d "{\"name\":\"$name\"}" > /dev/null 2>&1 || true
        fi
    done
}
