# agentboxes

Nix-based environment definitions for AI coding agents and multi-agent orchestrators.

## Why this exists

Setting up environments for AI agent orchestrators involves repetitive work: installing the orchestrator itself, adding required runtimes (Node.js, Python, Go), configuring CLI tools, and ensuring everything works together. Each orchestrator has different dependencies and setup steps.

agentboxes provides pre-built Nix definitions for these tools. You describe what you need in `agentbox.toml`, and Nix produces either a development shell or an OCI image—same config, same result, anywhere.

This is similar to what you could do with [devenv](https://devenv.sh), [devbox](https://www.jetify.com/devbox), or plain Nix flakes. The difference is that agentboxes has already packaged the orchestrators (schmux, gastown, openclaw, ralph) and agents (claude, codex, etc.), so you don't have to.

## Quick Start

```bash
# Enter a shell with schmux and all its dependencies
nix develop github:farra/agentboxes#schmux

# Or build an OCI image
just build-image schmux
```

## How to run these environments

agentboxes builds environments. How you run them depends on your needs:

| Method | Use when |
|--------|----------|
| `nix develop` | Exploring, testing, ephemeral use |
| Docker/Podman | Isolation from host, CI/CD, deployment |
| Distrobox | Want container isolation but with host $HOME access |
| Direct `nix shell` | Just need the tools in your current shell |

Each has tradeoffs:

- **nix develop**: Ephemeral. Environment disappears when you exit. No isolation from host filesystem.
- **Docker/Podman**: Isolated. Requires explicit volume mounts to persist state. Works everywhere containers run.
- **Distrobox**: Shares `$HOME` with host by default (convenient but less isolated). Persists between sessions. Linux only.

Choose based on your isolation and persistence requirements.

## Available Environments

### Orchestrators

| Name | Description | Guide |
|------|-------------|-------|
| `schmux` | Multi-agent tmux orchestrator | [docs](docs/orchestrators/schmux.md) |
| `gastown` | Multi-agent convoy orchestrator | [docs](docs/orchestrators/gastown.md) |
| `openclaw` | Multi-channel AI gateway | [docs](docs/orchestrators/openclaw.md) |
| `ralph` | Autonomous Claude Code runner | [docs](docs/orchestrators/ralph.md) |

### Agents

| Name | Description |
|------|-------------|
| `claude` | Claude Code CLI |
| `codex` | OpenAI Codex CLI |
| `gemini` | Google Gemini CLI |
| `opencode` | OpenCode CLI |

```bash
# Use an agent directly (without an orchestrator)
nix develop github:farra/agentboxes#claude
```

### Substrate

All environments include the **substrate layer**: git, curl, jq, ripgrep, fd, fzf, tmux, htop, and 50+ modern CLI tools.

## Project-Based Configuration

For project-specific environments, create an `agentbox.toml`:

```bash
mkdir my-ai-project && cd my-ai-project
nix flake init -t github:farra/agentboxes#project
```

This creates `flake.nix` and `agentbox.toml`. Edit the config:

```toml
[orchestrator]
name = "schmux"

agents = ["claude-code"]
bundles = ["baseline"]
packages = ["python312", "nodejs_22"]

[image]
name = "my-project"
tag = "latest"
```

Then:

```bash
# Ephemeral development
nix develop

# Or build a pre-baked image for deployment
just build-image my-project
```

## Distros

The `distros/` directory contains configurations for each orchestrator with baseline tools and claude-code agent.

| Distro | Orchestrator | Agents | Packages |
|--------|--------------|--------|----------|
| `schmux` | schmux | claude-code | python, nodejs |
| `gastown` | gastown | claude-code | python, nodejs, go |
| `openclaw` | openclaw | claude-code | nodejs, pnpm |
| `ralph` | ralph | claude-code | python, nodejs |

Use a distro as your starting point:

```bash
# Copy a distro config to your project
curl -O https://raw.githubusercontent.com/farra/agentboxes/main/distros/schmux.toml
mv schmux.toml agentbox.toml
```

## OCI Images

Images are built using a Containerfile that bakes all tools into a wolfi-toolbox base:

```bash
# Build an image (uses podman or docker)
just build-image schmux

# Create and enter a distrobox
just distrobox-create schmux
just distrobox-enter schmux

# Or test locally in one step
just test-local schmux
```

### Registry Operations

```bash
# Push to registry
just push-image schmux

# Build, tag, and push a release
just release schmux v1.0.0
```

### How it works

The Containerfile:
1. Starts from `wolfi-toolbox` base (distrobox-compatible)
2. Installs Nix using Determinate Systems installer
3. Runs `nix profile install .#<name>-env` to bake all tools

Images are ready to use immediately - no bootstrap or first-run installation needed.

## agentbox.toml Reference

```toml
# Image metadata
[image]
name = "my-project"
tag = "latest"
base = "wolfi"

# Orchestrator (optional)
[orchestrator]
name = "schmux"  # schmux | gastown | openclaw | ralph

# AI coding agents from numtide/llm-agents.nix
agents = ["claude-code", "codex", "gemini-cli", "opencode"]

# Tool bundles
bundles = ["baseline"]  # baseline (28 tools) or complete (61 tools)

# Rust toolchains (via rust-overlay)
# bundles = ["baseline", "rust-stable"]  # rust-stable | rust-beta | rust-nightly

# Exact nixpkgs package names
packages = ["python312", "nodejs_22", "go_1_24"]

# NUR packages (optional)
# packages = ["nur:owner/package"]
```

## Deploying to servers

Build and transfer an OCI image:

```bash
just build-image schmux
podman save ghcr.io/farra/agentboxes-schmux:latest | ssh server 'podman load'
```

Then run via Docker, Podman, distrobox, or any container runtime.

See the **[Deployment Guide](docs/deployment.md)** for registry publishing, team onboarding, and CI/CD examples.

## Project Structure

```
agentboxes/
├── flake.nix                    # Root flake with packages and devShells
├── justfile                     # Build commands (images, testing, dev)
├── lib/
│   ├── substrate.nix            # Common tools layer
│   ├── bundles.nix              # Tool bundles (baseline, complete)
│   ├── parseAgentboxConfig.nix  # Shared TOML parsing logic
│   ├── mkProjectShell.nix       # Compose devShell from agentbox.toml
│   └── mkProfilePackage.nix     # Build env for nix profile install
├── agents/                      # Agent wrappers (claude, codex, gemini, opencode)
├── orchestrators/               # Orchestrator definitions (schmux, gastown, etc.)
├── templates/project/           # Template for `nix flake init -t`
├── images/
│   └── Containerfile            # OCI image builder
├── distros/                     # Pre-configured orchestrator configs
└── docs/                        # Documentation
```

## Related Projects

- [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix) - Source for all agent packages
- [distrobox](https://github.com/89luca89/distrobox) - Run containers as if on host

## License

Apache-2.0
