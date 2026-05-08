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

use_tty() {
    if [ -t 0 ]; then
        return 0
    fi
    if [ -t 1 ]; then
        return 0
    fi
    return 1
}

TTY=""
if use_tty; then
    TTY="/dev/tty"
fi

echo "=== oh-my-openagent Subscription Setup ==="
echo ""
echo "This tool enhances OpenCode with advanced orchestration and AI providers."
echo "Answer the following questions to configure your subscriptions."
echo ""

read_with_tty() {
    local prompt="$1"
    local var_name="$2"
    local input_fd="$3"
    
    while true; do
        echo -n "$prompt [y/n]: "
        if [ -n "$TTY" ] && [ -r "$TTY" ]; then
            read -r answer < "$TTY"
        else
            read -r answer
        fi
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        case "$answer" in
            y|yes) 
                eval "$var_name=yes"
                return 0
                ;;
            n|no)
                eval "$var_name=no"
                return 0
                ;;
        esac
    done
}

read_claude_subscription() {
    while true; do
        echo -n "Do you have a Claude Pro/Max subscription? [y/n/max20]: "
        if [ -n "$TTY" ] && [ -r "$TTY" ]; then
            read -r claude_input < "$TTY"
        else
            read -r claude_input
        fi
        claude_input=$(echo "$claude_input" | tr '[:upper:]' '[:lower:]')
        case "$claude_input" in
            y|yes)
                CLAUDE_ANSWER="yes"
                while true; do
                    echo -n "  Are you on max20 (20x mode)? [y/n]: "
                    if [ -n "$TTY" ] && [ -r "$TTY" ]; then
                        read -r max20_input < "$TTY"
                    else
                        read -r max20_input
                    fi
                    max20_input=$(echo "$max20_input" | tr '[:upper:]' '[:lower:]')
                    case "$max20_input" in
                        y|yes)
                            CLAUDE_ANSWER="max20"
                            return 0
                            ;;
                        n|no)
                            return 0
                            ;;
                    esac
                done
                ;;
            n|no)
                CLAUDE_ANSWER="no"
                return 0
                ;;
            max20)
                CLAUDE_ANSWER="max20"
                return 0
                ;;
        esac
    done
}

if [ -n "$TTY" ] && [ -r "$TTY" ]; then
    echo "Using TTY for input..."
else
    echo "Warning: No TTY detected. You may need to run this interactively."
fi

read_claude_subscription
read_with_tty "Do you have an OpenAI/ChatGPT Plus subscription?" OPENAI_ANSWER
read_with_tty "Do you want to integrate Gemini models?" GEMINI_ANSWER
read_with_tty "Do you have a GitHub Copilot subscription?" COPILOT_ANSWER
read_with_tty "Do you have access to OpenCode Zen (opencode/ models)?" OPENCODE_ZEN_ANSWER
read_with_tty "Do you have a Z.ai Coding Plan subscription?" ZAI_CODING_PLAN_ANSWER
read_with_tty "Do you have an OpenCode Go subscription?" OPENCODE_GO_ANSWER

echo ""
echo "Installing oh-my-openagent with the following configuration:"
echo "  Claude: $CLAUDE_ANSWER"
echo "  OpenAI: $OPENAI_ANSWER"
echo "  Gemini: $GEMINI_ANSWER"
echo "  GitHub Copilot: $COPILOT_ANSWER"
echo "  OpenCode Zen: $OPENCODE_ZEN_ANSWER"
echo "  Z.ai Coding Plan: $ZAI_CODING_PLAN_ANSWER"
echo "  OpenCode Go: $OPENCODE_GO_ANSWER"
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
