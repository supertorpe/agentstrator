# Testing Packages for Agentstrator

This guide explains how to verify that a new agentstrator package installs, runs, and cleans up correctly. Use it when adding a new package or modifying an existing one.

The companion script `test-package.sh` (in the same directory as this guide) implements the automated checks described below.

## Quick Start

```bash
./test-package.sh rtk
```

Run `./test-package.sh --help` for available options.

## Overview

The test script (`test-package.sh`) performs 5 phases:

| Phase | What it checks |
|-------|---------------|
| validate | metadata, install.sh, uninstall.sh, init.sh, Dockerfile structure |
| build | docker build succeeds, file tracking works, smoke test |
| install | install.sh runs, config.json updated, MCP/plugin/instructions registered |
| runtime | generate_dockerfile includes package, runtime build succeeds, binary works |
| uninstall | uninstall.sh runs, cleanup complete, config restored |

## Running Tests

```bash
# Test a package by name (looks in ~/.agentstrator/packages/ and ./packages/)
./test-package.sh rtk

# Test a specific package directory
./test-package.sh --dir packages/rtk

# Skip slow phases (runtime build)
./test-package.sh --skip runtime rtk

# Always rebuild Docker images
./test-package.sh --rebuild rtk

# Set custom timeout for interactive packages (oh-my-openagent, etc.)
./test-package.sh --timeout 300 oh-my-openagent
```

## What Each Phase Verifies

### Validate
- `metadata` file exists with required `NAME=` field
- `install.sh` exists and is executable
- `uninstall.sh` exists and is executable
- `init.sh` is executable (if present)
- `Dockerfile` exists and uses `agentstrator-core` as base (if present)
- `Dockerfile` contains file-tracking pattern (`before-files.txt`, `after-files.txt`, `comm -13`) (if present)

### Build (Dockerfile-based packages only)
- `docker build -t agentstrator-<name>` succeeds
- `/new-files.txt` exists inside the image and is non-empty
- `/new-symlinks-with-targets.txt` exists if symlinks were created
- Binary smoke test: `<tool> --help` or `<tool> --version` works inside the image
- No system paths in new-files.txt (filters `/tmp/`, `/root/`)

### Install
- `install.sh` exits with code 0
- `config.json` marks the package as `installed: true`
- MCP server is registered in opencode.json (if install.sh uses `add_mcp_to_opencode`)
- Plugin reference is registered (if install.sh uses `add_plugin_to_opencode`)
- Instruction file exists and is registered (if install.sh uses `add_instructions_to_opencode`)

### Runtime
- `generate_dockerfile` output includes a `COPY --from=<name>` line for this package (if Dockerfile-based)
- Runtime image builds successfully with the package included
- Binary is accessible via `which <cmd>` in the runtime image

### Uninstall
- `uninstall.sh` exits with code 0
- `config.json` marks the package as `installed: false`
- Previously registered MCP/plugin/instructions entries are removed
- Config file is restored to pre-install state (`restore_config` is idempotent — safe if called multiple times)

## Installation Behavior Notes

- **install.sh does NOT update config.json** — the agentstrator framework does this after a successful `agentstrator install` run. The test script handles this by injecting the package entry into config.json after install.sh completes. This means the install phase may pass even if config.json is not updated by the package scripts themselves.
- **MCP entry key** is the package name (2nd arg to `add_mcp_to_opencode`), NOT necessarily `command[0]`. For example, `agentmemory` registers with key `"agentmemory"` but `command[0]` is `"npx"`. The test script checks the entry key via `.mcp | has("<name>")`.
- **Timeout**: The `--timeout` flag wraps install.sh and uninstall.sh with the `timeout` command. Default is 120 seconds. Set to `0` to disable.

## State Isolation

The install and uninstall phases modify `config.json` and opencode configuration files. The script:

1. Backs up `config.json` before install
2. Backs up `opencode.json` before install
3. Restores both after uninstall completes (backup vars cleared after restore to prevent double-restore)

This makes it safe to run on a production installation.

## Package Pattern Reference

| Pattern | Dockerfile | install.sh uses | Phase notes |
|---------|-----------|-----------------|-------------|
| A (NPM global) | Yes | npm install -g | Build, Install, Runtime, Uninstall |
| B (Python pip) | Yes | pip3 install | Build, Install, Runtime, Uninstall |
| C (binary download) | Yes | curl \| sh | Build, Install, Runtime, Uninstall |
| D (git plugin) | No | add_plugin_to_opencode | Install, Uninstall only |
| E (instructions) | No | add_instructions_to_opencode | Install, Uninstall only |
| F (interactive) | No | npm install + docker run | Install, Uninstall only (no automated smoke test) |

## Extended Checklist

Use this in addition to the checklist in `adding-packages.md` when adding a new package:

- [ ] `./test-package.sh <name>` passes all 5 phases
- [ ] `agentstrator install <name>` works (single-package install)
- [ ] `agentstrator remove <name>` works (single-package remove, cleanup verified)
- [ ] `agentstrator rebuild` succeeds without breaking other packages
- [ ] Runtime image binary: `docker run --rm agentstrator:runtime which <cmd>` returns the binary
- [ ] `init.sh` exits cleanly (if present)
- [ ] PATH correctly set for non-standard paths (if `PATH=` in metadata)

## Known Package Bugs (Cross-Referenced)

The following bugs were discovered during testing and should be fixed:

| Package | Issue |
|---------|-------|
| `mempalace` | Uninstall removes MCP key `"mempalace-mcp"` but install creates key `"mempalace"` — mismatch |
| `codedna` | `init.sh` checks `$WORKSPACE/bmalph/config.json` instead of `$WORKSPACE/.codedna` — copy-paste from bmalph |
| `oh-my-openagent` | `install.sh` prompts 7 interactive questions — requires `--timeout` or `DEBIAN_FRONTEND=noninteractive` |

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Build fails | Dockerfile doesn't use `agentstrator-core` as base, or package install command fails |
| `/new-files.txt` empty | File-tracking pattern missing in Dockerfile |
| Smoke test fails | Binary not in PATH or different binary name than expected |
| Install phase fails | `install.sh` calls `add_mcp_to_opencode` but `node:22-slim` image not available |
| Runtime build fails | `generate_dockerfile` produces invalid Dockerfile or package has conflicting files |
| Install phase hangs | Package has interactive prompts — use `--timeout 300` or higher |
| MCP check fails in install but succeeds in uninstall | Package uses different MCP key name than `CANONICAL_NAME` — check install.sh for `add_mcp_to_opencode` args |
| config.json check fails | Expected: install.sh doesn't update config.json (framework does). Test injects it automatically. |

## Adding Tests for a New Pattern

If a package introduces a new pattern (not one of the 6 above), add corresponding checks to `test-package.sh`:

1. Add detection logic in the pattern detection section
2. Add check functions in the relevant phase
3. Update this guide's pattern reference table
