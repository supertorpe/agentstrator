# Contributing to Agentstrator

## Issues

Report bugs and suggest features via [GitHub Issues](https://github.com/supertorpe/agentstrator/issues).

## Pull Requests

1. Fork and create a feature branch from `main`.
2. If adding a package, see [`adding-packages.md`](adding-packages.md) for the full guide.
3. Test your changes locally before submitting.
4. Open a PR against `main` with a clear description of what and why.

### Testing locally

```bash
# Copy local changes to an existing installation for fast iteration
cp lib/*.sh ~/.agentstrator/lib/
cp agentstrator ~/.local/bin/

# Rebuild runtime image
agentstrator rebuild

# Test with a container
agentstrator --shell
```

## Code style

- **Shell scripts**: `bash` with `set -e`, 2-space indent, `snake_case` variables. Prefer helper functions from `commons.sh` over reimplementing patterns.
- **Python services** (`services/registry/`): standard Python conventions.
- **Dockerfiles**: use `agentstrator-core` as base, include the file-tracking pattern (`before-files.txt` / `after-files.txt` / `comm -13`).

## Project structure

| Path | Purpose |
|------|---------|
| `agentstrator` | Main CLI entrypoint |
| `install.sh` | One-curl install script |
| `lib/` | Shared shell libraries (cli, build, config, commons) |
| `core/` | Core Dockerfile and bootstrap |
| `packages/` | Optional tool packages (each with install.sh, uninstall.sh, metadata, optional Dockerfile) |
| `services/` | Bridge services (telegram, discord) and registry |
| `docs/` | Supplementary documentation |
| `packages.json` | Menu categories and package listing |

## Adding or modifying a package

See [`adding-packages.md`](adding-packages.md) for the complete guide covering metadata format, Dockerfile patterns, install/uninstall scripts, and init hooks.
