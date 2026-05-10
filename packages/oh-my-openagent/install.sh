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

# Env var overrides (set before running install.sh in non-interactive contexts)
#   OHMYOPENAGENT_CLAUDE=yes|no|max20
#   OHMYOPENAGENT_OPENAI=yes|no
#   OHMYOPENAGENT_GEMINI=yes|no
#   OHMYOPENAGENT_COPILOT=yes|no
#   OHMYOPENAGENT_ZEN=yes|no
#   OHMYOPENAGENT_ZAI=yes|no
#   OHMYOPENAGENT_GO=yes|no

use_tty() {
    [ -t 0 ] || [ -t 1 ]
}

TTY=""
use_tty && TTY="/dev/tty"

prompt_yn() {
    local prompt="$1" var_name="$2" env_override="$3"
    [ -n "$env_override" ] && { eval "$var_name=$env_override"; return 0; }
    [ -z "$TTY" ] && { eval "$var_name=no"; return 0; }
    while true; do
        echo -n "$prompt [y/n]: "
        read -r answer < /dev/tty 2>/dev/null || read -r answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        case "$answer" in y|yes) eval "$var_name=yes"; return 0;; n|no) eval "$var_name=no"; return 0;; esac
    done
}

prompt_claude() {
    local env_val="${OHMYOPENAGENT_CLAUDE:-}"
    [ -n "$env_val" ] && { CLAUDE_ANSWER="$env_val"; return 0; }
    [ -z "$TTY" ] && { CLAUDE_ANSWER="no"; return 0; }
    while true; do
        echo -n "Do you have a Claude Pro/Max subscription? [y/n/max20]: "
        read -r input < /dev/tty 2>/dev/null || read -r input
        input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
        case "$input" in
            y|yes)
                CLAUDE_ANSWER="yes"
                while true; do
                    echo -n "  Are you on max20 (20x mode)? [y/n]: "
                    read -r m < /dev/tty 2>/dev/null || read -r m
                    case "$(echo "$m" | tr '[:upper:]' '[:lower:]')" in y|yes) CLAUDE_ANSWER="max20"; return 0;; n|no) return 0;; esac
                done
                ;;
            n|no) CLAUDE_ANSWER="no"; return 0;;
            max20) CLAUDE_ANSWER="max20"; return 0;;
        esac
    done
}

echo "=== oh-my-openagent Subscription Setup ==="
echo ""

prompt_claude
prompt_yn "Do you have an OpenAI/ChatGPT Plus subscription?" OPENAI_ANSWER "${OHMYOPENAGENT_OPENAI:-}"
prompt_yn "Do you want to integrate Gemini models?" GEMINI_ANSWER "${OHMYOPENAGENT_GEMINI:-}"
prompt_yn "Do you have a GitHub Copilot subscription?" COPILOT_ANSWER "${OHMYOPENAGENT_COPILOT:-}"
prompt_yn "Do you have access to OpenCode Zen (opencode/ models)?" OPENCODE_ZEN_ANSWER "${OHMYOPENAGENT_ZEN:-}"
prompt_yn "Do you have a Z.ai Coding Plan subscription?" ZAI_CODING_PLAN_ANSWER "${OHMYOPENAGENT_ZAI:-}"
prompt_yn "Do you have an OpenCode Go subscription?" OPENCODE_GO_ANSWER "${OHMYOPENAGENT_GO:-}"

echo "Installing oh-my-openagent with: Claude=$CLAUDE_ANSWER OpenAI=$OPENAI_ANSWER Gemini=$GEMINI_ANSWER Copilot=$COPILOT_ANSWER Zen=$OPENCODE_ZEN_ANSWER Zai=$ZAI_CODING_PLAN_ANSWER Go=$OPENCODE_GO_ANSWER"
echo ""

BUILD_FLAGS="--no-tui --claude=$CLAUDE_ANSWER --openai=$OPENAI_ANSWER --gemini=$GEMINI_ANSWER --copilot=$COPILOT_ANSWER --opencode-zen=$OPENCODE_ZEN_ANSWER --zai-coding-plan=$ZAI_CODING_PLAN_ANSWER --opencode-go=$OPENCODE_GO_ANSWER"

echo "Running oh-my-opencode installer, be patient..."
docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    -e "HOME=/agentstrator" \
    -e "OPENCODE_CONFIG=/agentstrator/.config/opencode/opencode.json" \
    -e "OPENCODE_CONFIG_DIR=/agentstrator/.config/opencode" \
    -e "XDG_CONFIG_HOME=/agentstrator" \
    -w /tmp agentstrator-core bash -c "
    export HOME=/agentstrator
    export XDG_CONFIG_HOME=/agentstrator
    npm install oh-my-opencode
    node node_modules/oh-my-opencode/bin/oh-my-opencode.js install $BUILD_FLAGS
"

echo ""
echo "oh-my-openagent installed successfully!"
echo ""
