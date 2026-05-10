# Adding New Packages to Agentstrator

This guide explains how to add a new package to agentstrator. Packages are optional components that users can toggle on/off in the `agentstrator setup` TUI menu. Each tool lives in its own directory under `agentstrator/packages/` and is fully self-contained.

## Installation Architecture

Packages are installed in two stages:

1. **Build stage** (`agentstrator setup`): Each package with a `Dockerfile` is built into a standalone image (`agentstrator-<name>`). These are intermediate images used only to extract binaries and files.
2. **Runtime stage**: All installed package images are merged into a single `agentstrator:runtime` image via auto-generated `COPY --from=<pkg>` commands in `lib/build-runtime.sh`. Packages without Dockerfiles run install scripts directly on the volume (config-only, skills, plugins).

## Directory Structure

Create a new directory for your tool:

```
agentstrator/packages/mytool/
├── Dockerfile        # Optional: builds a standalone image (omit for config-only)
├── install.sh        # Required: installs the tool
├── metadata          # Required: tool metadata (key=value format)
├── init.sh           # Optional: runs before opencode starts, once per workspace
└── uninstall.sh      # Required: removes the tool
```

### metadata file

Contains key-value pairs describing the tool. Newline-separated `KEY=VALUE` lines.

```
NAME=mytool
DESCRIPTION=Short description.
SOURCE=https://github.com/example/agentstrator/tree/main/packages/mytool
COMMANDS=mycmd,myothercmd
```

| Field | Required | Description |
|-------|----------|-------------|
| `NAME` | Yes | Display name in the TUI menu and config key |
| `DESCRIPTION` | No | Shown in the TUI menu (max 50 characters) |
| `SOURCE` | No | Link to source code |
| `COMMANDS` | No | Comma-separated list of binaries this package provides (for agent awareness) |
| `PATH` | No | Non-standard paths to add to `$PATH` in the container (e.g., `PATH=/usr/local/lib/node_modules/bmalph/bin`). Standard paths (`/usr/local/bin`, etc.) are already in the container PATH. |
| `ENV` | No | Zero or more `ENV=` lines — each sets an environment variable in the runtime container (e.g., `PORT=3333`) |
| `RUN` | No | Command to run as a background daemon at container startup. Use `setsid ... >/dev/null 2>&1 &` pattern |

**Note:** `PATH=` in metadata is only needed for non-standard installation paths. The container PATH is hardcoded in `lib/cli.sh` to include `/usr/local/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`. Packages that install binaries to standard paths are automatically available.

For packages that install to custom locations (e.g., `/usr/local/lib/node_modules/bmalph/bin`), use `PATH=` to add those directories:

```
PATH=/usr/local/lib/node_modules/bmalph/bin
```

Python packages that install to `/usr/local/lib/python3.11/dist-packages` don't need `PATH=` since they're accessed via `python3 -m <module>` or entry points in `/usr/local/bin`.

### Menu Ordering

Packages are displayed in the TUI menu via `packages.json` (fetched from GitHub by `packages.sh`):

```json
[
  {
    "category": "Token Compression",
    "packages": ["lean-ctx", "caveman"]
  },
  {
    "category": "Persistent Memory",
    "packages": ["mempalace"]
  }
]
```

- Categories are displayed top-to-bottom in array order
- Packages within a category are displayed left-to-right
- Packages on disk but **not** in `packages.json` appear in an "Other" section at the bottom
- Packages in `packages.json` but **not** on disk are silently skipped

## install.sh

Runs when the user enables the tool in `agentstrator setup`. Available variables (set by the installer):

| Variable | Description |
|----------|-------------|
| `AGENTSTRATOR_INSTALL_DIR` | Absolute path to `~/.agentstrator` |
| `VOLUME` | Absolute path to `~/.agentstrator/volume` |
| `COMPONENT_DIR` | Absolute path to the tool's directory |
| `CONFIG_DIR` | Same as `AGENTSTRATOR_INSTALL_DIR` |

Available helper functions (from `commons.sh`, source it when needed):

| Function | Description |
|----------|-------------|
| `prompt_copy_config <host_path> <volume_path>` | Prompts to copy an existing host config file into the volume |
| `ensure_network` | Creates `agentstrator-net` Docker network if it doesn't exist |
| `get_tty` | Returns `/dev/tty` if a terminal is available, empty string otherwise |
| `env_set <file> <key> <value>` | Sets or updates a key in a `.env` file |
| `env_remove <file> <key>` | Removes a key from a `.env` file |
| `add_mcp_to_opencode <volume> <name> <command_json>` | Adds an MCP server entry to `opencode.json` |
| `remove_mcp_from_opencode <volume> <name>` | Removes an MCP server entry from `opencode.json` |
| `add_plugin_to_opencode <volume> <plugin_ref>` | Adds a plugin reference to `opencode.json` |
| `remove_plugin_from_opencode <volume> <plugin_ref>` | Removes a plugin reference from `opencode.json` |
| `add_instructions_to_opencode <volume> <instruction>` | Adds an instructions file reference to `opencode.json` |
| `remove_instructions_from_opencode <volume> <instruction>` | Removes an instructions file reference |

## uninstall.sh

Runs when the user disables the tool. Should reverse everything `install.sh` does — remove config files, unregister MCP/plugin entries, clean up skills, etc.

## init.sh (optional)

Runs before opencode starts, once per workspace. Receives two arguments: `<workspace_dir> <volume_dir>`. Use for one-time project initialization (mempalace init, bmalph init, graphify install). Runs interactively so can prompt for user input.

## Dockerfile (if present)

All package Dockerfiles use `agentstrator-core` as the base image (which has git, node, npm, opencode, python3, pip3, libgtk-3, libwebkit2gtk). Every Dockerfile **must** include the file-tracking pattern used by `lib/build-runtime.sh`:

```dockerfile
FROM agentstrator-core

RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt

# Install your tool
RUN npm install -g mytool@latest
# or: RUN pip3 install --break-system-packages mytool
# or: RUN curl -fsSL https://example.com/install.sh | sh
# or: RUN apt-get install -y mytool

RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt

RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt

RUN mytool --help >/dev/null 2>&1 && echo "mytool OK" || echo "mytool FAIL"
```

The build system reads `/new-files.txt` to generate minimal `COPY --from=<pkg>` commands, and `/new-symlinks-with-targets.txt` to recreate symlinks in the runtime image.

## Current Package Patterns

There are **6 patterns** across the 15 current packages:

---

### Pattern A: NPM Global Package

For tools installed via `npm install -g`. Most common pattern.

**Packages:** `agent-browser`, `bmalph`, `continues`, `context-mode`, `openspec`, `playwright-cli`, `tokenscope`, `tokscale`

**Dockerfile:**
```dockerfile
FROM agentstrator-core
RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt
RUN npm install -g mytool@latest
RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt
RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt
RUN mytool --help >/dev/null 2>&1 && echo "mytool OK" || echo "mytool FAIL"
```



**Variants with extra system deps:** `agent-browser` and `playwright-cli` install browser libraries (libglib, libnspr, libnss, libatk, libcups, libgbm, etc.) for Playwright/Chromium compatibility.

---

### Pattern B: Python PIP Package

For tools installed via `pip3 install`.

**Packages:** `graphify`, `mempalace`

**Dockerfile:**
```dockerfile
FROM agentstrator-core
RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt
RUN pip3 install --break-system-packages mytool
RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt
RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt
RUN python3 -m mytool --help >/dev/null 2>&1 && echo "mytool OK" || echo "mytool FAIL"
```

**metadata:** `COMMANDS=mycmd,myothercmd` (optional, for agent awareness)

**install.sh:** May create config dirs, init data (e.g., `mempalace` creates `.mempalace/` with `identity.txt` and `wing_config.json`), and register MCP servers via `add_mcp_to_opencode`.

**init.sh:** Runs per-workspace setup (mempalace init, graphify install).

---

### Pattern C: Binary Download (curl | sh)

For tools installed via a curl-piped-to-shell script.

**Packages:** `lean-ctx`, `rtk`, `sentrux`

**Dockerfile:** Same file-tracking pattern, but install via:
```dockerfile
RUN curl -fsSL https://example.com/install.sh | sh
```
Or for specific paths:
```dockerfile
RUN mkdir -p /usr/local/bin && \
    curl -fsSL https://example.com/install.sh | RTK_INSTALL_DIR=/usr/local/bin sh
```

 (or no PATH for tools like `sentrux` that don't expose CLI)

**install.sh:** May register MCP servers (`sentrux`, `lean-ctx`), copy host config (`rtk`), or copy skill rules (`lean-ctx`).

**Note:** `lean-ctx` metadata also includes `ENV=BASH_ENV=...`, `ENV=CLAUDE_ENV_FILE=...`, `PORT=3333`, and `RUN=setsid lean-ctx dashboard ...` for daemon auto-start.

---

### Pattern D: Git-Repository Plugin

For packages that provide OpenCode plugins (git repos).

**Packages:** `superpowers`, `tokenscope`

**No Dockerfile.** These add a plugin reference to `opencode.json`:

**install.sh:**
```bash
add_plugin_to_opencode "$VOLUME" "mytool@git+https://github.com/example/mytool.git"
```

**uninstall.sh:**
```bash
remove_plugin_from_opencode "$VOLUME" "mytool@git+https://github.com/example/mytool.git"
```

**metadata:** No `PATH` line.

---

### Pattern E: Instructions/Skills Injection

For packages that add markdown instructions or skill files to the OpenCode config.

**Packages:** `caveman`

**No Dockerfile.** Downloads a markdown file and registers it as instructions:

**install.sh:**
```bash
curl -fsSL "$URL" > "$VOLUME/.config/opencode/caveman.md"
add_instructions_to_opencode "$VOLUME" "/agentstrator/.config/opencode/caveman.md"
```

**uninstall.sh:**
```bash
rm -f "$VOLUME/.config/opencode/caveman.md"
remove_instructions_from_opencode "$VOLUME" "/agentstrator/.config/opencode/caveman.md"
```

**metadata:** No `PATH` line.

---

### Pattern F: Interactive Setup Runner

For packages that need TTY-based user interaction during installation (sub prompts, API keys, subscription toggles).

**Packages:** `oh-my-openagent`

**No Dockerfile** — runs inside `agentstrator-core` container using the npm package's own installer:

**install.sh:**
```bash
read_with_tty() { ... }  # Custom TTY read helpers
read_claude_subscription() { ... }  # Subscription-specific prompts
# Collect user answers, then run:
docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    -e "HOME=/agentstrator" \
    agentstrator-core:latest bash -c "
    npm install oh-my-opencode
    node node_modules/oh-my-opencode/bin/oh-my-opencode.js install $BUILD_FLAGS
"
```

Uses `get_tty` from commons.sh for interactive input. Registers itself as an OpenCode plugin.

**metadata:** No `PATH` line.

---

### Pattern G: Browser Runtime with Skills

For packages that install browser automation tools and copy skill files onto the volume.

**Packages:** `agent-browser`, `playwright-cli`

These are NPM packages (Pattern A) with extra steps in install.sh to copy skill data:

**install.sh (agent-browser):**
```bash
docker run --rm -u $(id -u):$(id -g) \
    -v "$VOLUME:/agentstrator" \
    agentstrator-agent-browser:latest bash -c "
    export HOME=/agentstrator
    agent-browser install --with-deps
    cp -r /usr/local/lib/node_modules/agent-browser/skill-data/* /agentstrator/.config/opencode/skills/
"
```

**Dockerfile:** Includes browser library deps (libglib, libnspr, libnss, libatk, libcups, libxkbcommon, libgbm, libcairo, etc.).

**metadata:** May include `ENV=AGENT_BROWSER_SKILLS_DIR=...` lines.

**uninstall.sh:** Removes skill dirs and config files.

---

## Summary of All Packages

| Package | Pattern | Dockerfile | init.sh | MCP | Plugin | Instructions | Interactive |
|---------|---------|------------|---------|-----|--------|-------------|-------------|
| agent-browser | A+G (NPM + skills) | Yes | No | No | No | No | No |
| bmalph | A (NPM) | Yes | Yes | No | No | No | No |
| caveman | E (instructions) | No | No | No | No | Yes | No |
| continues | A (NPM) | Yes | No | No | No | No | No |
| graphify | B (pip) | Yes | Yes | No | No | No | No |
| lean-ctx | C (binary) | Yes | No | Yes | No | No | No |
| mempalace | B (pip) | Yes | Yes | Yes | No | No | No |
| oh-my-openagent | F (interactive) | No | No | No | Yes | No | Yes |
| openspec | A (NPM) | Yes | No | No | No | No | No |
| playwright-cli | A+G (NPM + skills) | Yes | No | No | No | No | No |
| rtk | C (binary) | Yes | No | No | No | No | No |
| sentrux | C (binary) | Yes | No | Yes | No | No | No |
| superpowers | D (plugin) | No | No | No | Yes | No | No |
| tokenscope | D (plugin) | No | No | No | Yes | No | No |
| tokscale | A (NPM) | Yes | No | No | No | No | No |

## Updating README.md

After adding a new package, add it to the package table in `README.md` (under the appropriate category section — e.g., Token Compression, Workflows, etc.). This keeps the package catalog visible to users browsing the repository.

## Testing Your Tool

1. **Build image:** `docker build -t agentstrator-mytool packages/mytool/`
2. **Install in setup:** Run `agentstrator setup`, navigate to your tool, toggle it on, press Enter.
3. **Verify runtime:** After the runtime image builds, start a container and check:
   - Binary is accessible: `which mytool`
   - MCP works (if applicable): check `opencode.json` for the entry
   - Skills are in place: `ls ~/.config/opencode/skills/`
4. **Uninstall:** Run `agentstrator setup`, toggle off, verify cleanup.

## Checklist

- [ ] `metadata` has `NAME=` (add `COMMANDS=` if the tool provides CLI commands, add `ENV=`/`PORT=`/`RUN=` if needed for daemon or env)
- [ ] `install.sh` is executable (`chmod +x`)
- [ ] `uninstall.sh` is executable and reverses all install.sh changes
- [ ] `Dockerfile` uses `agentstrator-core` as base (if present)
- [ ] Dockerfile includes the file-tracking pattern (`before-files.txt`, `after-files.txt`, `comm -13`, symlink tracking)
- [ ] Package name added to `packages.json` (or left out for "Other" section)
- [ ] `init.sh` handles missing workspace gracefully (exits early if `$WORKSPACE` is empty or doesn't exist)
- [ ] MCP registration uses `add_mcp_to_opencode` / `remove_mcp_from_opencode` helpers
- [ ] Plugin registration uses `add_plugin_to_opencode` / `remove_plugin_from_opencode` helpers
- [ ] Instructions registration uses `add_instructions_to_opencode` / `remove_instructions_from_opencode` helpers

## Testing Checklist

After adding a new package, verify it works correctly:

- [ ] `./test-package.sh <name>` passes all phases
- [ ] `agentstrator install <name>` works (single-package install)
- [ ] `agentstrator remove <name>` works (single-package remove, cleanup verified)
- [ ] `agentstrator rebuild` succeeds without breaking other packages
- [ ] `docker run --rm agentstrator:runtime which <cmd>` returns the binary
- [ ] `init.sh` exits cleanly (if present)
- [ ] PATH correctly set for non-standard paths (if `PATH=` in metadata)