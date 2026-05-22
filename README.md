# Agentstrator

Agentstrator runs [OpenCode](https://opencode.ai) as a **sidecar container**, capable of attaching to and controlling pre-existing development containers without needing to modify their images to add AI agents, skills, commands, or packages.
It also works standalone, running OpenCode directly without attaching to any dev container — for working on local projects, orchestrating workflows, or using agent packages independently. No need to install OpenCode, SDKs, or agent packages inside your project images — the agent lives alongside them, not inside them.

## How it works

```
 ┌────────────────────────────────────────────────────────┐
 │ ┌────────────────┐       ┌─────────────────────────┐   │
 │ │┌───────────────┴─┐     │ ┌───────────────────────┴─┐ │
 │ ││  Dev Container  │     │ │ agentstrator:runtime    │ │
 │ ││   (your app)   ◄┼─────┼─┼  - opencode             │ │
 │ └┼   No changes    │     │ │  - packages (optional)  │ │
 │  │     needed      │     └─┤    tools, workflows...  │ │
 │  └─────────────────┘       └─▲──────────┬───────▲────┘ │
 │                              │          │       │      │
 │                              │          │       │      │
 │                              │    ┌─────▼────┐  │      │
 │                              │    │          │  │      │
 │                              │    │ Registry │  │      │
 │                              │    │          │  │      │
 │                              │    └─▲──────▲─┘  │      │
 │                              │      │      │    │      │
 │                              │      │      │    │      │
 │                            ┌─┴──────┴─┐┌───┴────┴─┐    │
 │                            │ Telegram ││ Discord  │    │
 │                            │  bridge  ││  bridge  │    │
 │                            └──────────┘└──────────┘    │
 └────────────────────────────────────────────────────────┘
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/supertorpe/agentstrator/main/install.sh | bash
```

Run `agentstrator setup` anytime for an interactive configuration where you choose which packages to install or uninstall.

## Usage

```bash
agentstrator                    # Show a menu to choose the running mode
agentstrator --cli              # Launch OpenCode in client mode
agentstrator --srv              # Launch OpenCode in server mode (registers with registry)
agentstrator --dev CONTAINER    # Attach to an existing dev container
agentstrator --shell            # Open a shell in a new agentstrator container, mapping current directory
agentstrator setup              # Re-run interactive setup
agentstrator install <pkg>      # Install a specific package
agentstrator remove <pkg>       # Remove a package
agentstrator rebuild            # Rebuild all packages
agentstrator upgrade            # Check GitHub for updates, download and rebuild
agentstrator status             # Check current vs latest version
agentstrator services <cmd>     # Manage bridge services (start/stop/logs)
```

## Image layers

```
agentstrator:base       ← debian-bookworm + system tools (curl, git, jq, python, node)
  └─ agentstrator:core  ← opencode-ai only
       └─ agentstrator:runtime  ← core + all installed packages merged into one image
```

The `runtime` image is what runs as the sidecar. Base is stable and never rebuilt. Core and runtime are rebuilt on `upgrade` and `rebuild`.

## Packages

Agentstrator packages install inside the Docker image, not on the host. They're available to the agent without modifying your development containers. See [`adding-packages.md`](adding-packages.md) to add new ones.

### Token Compression & Monitoring
| Package        | Description                                     |
|----------------|-------------------------------------------------|
| [`rtk`](https://github.com/rtk-ai/rtk)          | Filters and compresses command outputs          |
| [`lean-ctx`](https://github.com/yvgude/lean-ctx)          | Reduces LLM token consumption up to 99%         |
| [`context-mode`](https://github.com/mksglu/context-mode)  | Context window optimization                     |
| [`caveman`](https://github.com/JuliusBrussee/caveman)      | Cuts 65% of tokens by talking like caveman      |
| [`tokscale`](https://github.com/junhoyeo/tokscale)         | Token usage tracker and visualization dashboard |
| [`tokenscope`](https://github.com/ramtinJ95/opencode-tokenscope) | Token usage analysis and cost tracking          |

### Workflows & Orchestration
| Package           | Description                                        |
|-------------------|----------------------------------------------------|
| [`continues`](https://github.com/yigitkonur/cli-continues)       | Resume coding sessions                             |
| [`superpowers`](https://github.com/obra/superpowers)     | Complete software development methodology          |
| [`oh-my-openagent`](https://github.com/code-yeongyu/oh-my-openagent) | Advanced orchestration with workflow automation    |
| [`ijfw`](https://gitlab.com/therealseandonahoe/ijfw)       | Memory, routing, audits, workflow                   |
| [`gentle-ai`](https://github.com/Gentleman-Programming/gentle-ai)       | SDD workflow, memory, and skills                   |
| [`nwave`](https://github.com/nWave-ai/nWave)           | AI agents that guide you from idea to working code |
| [`openspec`](https://github.com/Fission-AI/OpenSpec)        | Spec-driven development                            |
| [`bmalph`](https://github.com/LarsCowe/bmalph)          | BMAD-METHOD with Ralph                             |
| [`agent-skills`](https://github.com/addyosmani/agent-skills)    | Engineering skills and workflows                   |

### Memory / Knowledge / Understanding
| Package     | Description |
|-------------|---------------------------------------------------|
| [`graphify`](https://github.com/safishamsi/graphify)  | Knowledge graph builder                           |
| [`mempalace`](https://github.com/MemPalace/mempalace) | AI memory system                                  |
| [`agentmemory`](https://github.com/rohitg00/agentmemory) | Persistent memory for AI coding agents        |
| [`codegraph`](https://github.com/colbymchenry/codegraph)   | Semantic knowledge graph of codebases       |
| [`codedna`](https://github.com/Larens94/codedna)   | In-source annotation protocol for AI agents       |
| [`leankg`](https://github.com/FreePeak/LeanKG)    | Lightweight knowledge graph with MCP for AI tools |

### Developer Tools
| Package          | Description            |
|------------------|------------------------|
| [`playwright-cli`](https://github.com/microsoft/playwright-cli) | Browser automation     |
| [`agent-browser`](https://github.com/vercel-labs/agent-browser)  | Browser automation     |
| [`sentrux`](https://github.com/sentrux/sentrux)        | AI code quality sensor |

## Bridges: Telegram & Discord

Agentstrator includes optional bridge services that connect a Telegram bot and/or a Discord bot to your running OpenCode instances. Configure them during `agentstrator setup` and start them with:

```bash
agentstrator services start
```

All communication goes through the registry, so the bridges work in both single-node and multi-node setups.

## Setting Up Bots

### Telegram Bot Setup

1. **Create a bot via @BotFather:**
   - Open Telegram and search for `@BotFather`
   - Send `/newbot`
   - Choose a display name (e.g., "My AI Assistant")
   - Choose a username ending in `bot` (e.g., `my_ai_assistant_bot`)
   - BotFather will give you a token like `123456789:ABCdef...`

2. **Configure the token:**
   - During `agentstrator setup`, you'll be prompted for the Telegram Bot Token
   - Or edit `$HOME/.agentstrator/.env` directly:
     ```
     TELEGRAM_BOT_TOKEN=your-bot-token-here
     ```

3. **Restrict access (optional):**
   - Set `TELEGRAM_ALLOWED_USERS` to comma-separated Telegram usernames (without `@`):
     ```
     TELEGRAM_ALLOWED_USERS=username1,username2
     ```
   - Leave empty to allow all users

4. **Start the service:**
   ```bash
   ./agentstrator services start
   ```

5. **Use the bot:**
   - Open a chat with your bot in Telegram
   - Send `/agents` to see available agents
   - Select an agent, mode, and session to start interacting

### Discord Bot Setup

1. **Create a Discord Application:**
   - Go to the [Discord Developer Portal](https://discord.com/developers/applications)
   - Click "New Application" and give it a name
   - Go to the "Installation" section in the left sidebar
   - Select "None" in "Install Link" dropdown
   - Click "Save changes"
   - Go to the "Bot" section in the left sidebar
   - Uncheck "Public Bot"
   - Check "Presence Intent", "Server Members Intent" and "Message Content Intent"
   - Click "Reset Token" and copy the token generated into a safe place
   - Click "Save changes"

2. **Invite the bot to your server:**
   - Go to "OAuth2" section in the left sidebar → "URL Generator"
   - Select scopes: `bot`, `applications.commands`
   - Select bot permissions:
     - **Text Permissions**: `Send Messages`, `Send Messages in Threads`, `Read Message History`, `Embed Links`, `Attach Files`
     - **General Permissions**: None required
   - Copy the generated URL and open it in your browser
   - Select the server to invite the bot to

3. **Configure the token:**
   - During `agentstrator setup`, select `discord` and you'll be prompted for the Discord Bot Token and allowed users
   - Or edit `$HOME/.agentstrator/.env` directly:
     ```
     DISCORD_BOT_TOKEN=your-discord-token-here
     ```

4. **Restrict access (optional):**
   - Set `DISCORD_ALLOWED_USERS` to comma-separated Discord **user IDs** or usernames:
     ```
     DISCORD_ALLOWED_USERS=123456789012345678,username1
     ```
   - To find a user ID: enable Developer Mode in Discord (Settings → Advanced → Developer Mode), then right-click a user → "Copy User ID"
   - Leave empty to allow all users

5. **Start the service:**
   ```bash
   ./agentstrator services start
   ```

6. **Use the bot:**
   - In any channel or DM, use slash commands:
     - `/agents` - Select an agent to interact with
     - `/sessions` - View and manage your sessions
     - `/mode` - Switch the active session mode
     - `/log` - View session conversation logs
     - `/help` - Show available commands
   - **In channels**: Mention the bot with `@bot_name your message` to send messages to the active agent
   - **In DMs**: Just type your message directly — no mention needed

## Multi-node deployments

Agentstrator supports two modes:

- **Single node** — file-based registry, no external dependencies
- **Multi node** — registry service for agent discovery across machines

The multi-node setup runs a registry service (`services/registry/`) that agents register with. Bridges and other agents discover each other through this registry. Configure during `agentstrator setup`.
