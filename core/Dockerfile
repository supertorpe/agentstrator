FROM agentstrator-base

RUN npm install -g opencode-ai

RUN opencode --help >/dev/null 2>&1 && echo "opencode OK" || echo "opencode FAIL"