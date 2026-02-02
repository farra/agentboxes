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
nix build github:farra/agentboxes#schmux-image
```

## How to run these environments

agentboxes builds environments. How you run them depends on your needs:

| Method | Use when |
|--------|----------|
| `nix develop` | Exploring, testing, ephemeral use |
| Docker | Isolation from host, CI/CD, deployment |
| Distrobox | Want container isolation but with host $HOME access |
| Direct `nix shell` | Just need the tools in your current shell |

Each has tradeoffs:

- **nix develop**: Ephemeral. Environment disappears when you exit. No isolation from host filesystem.
- **Docker**: Isolated. Requires explicit volume mounts to persist state. Works everywhere Docker runs.
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

[bundles]
include = ["complete"]

[tools]
python = "3.12"
nodejs = "20"

[llm-agents]
include = ["claude-code"]
```

Then:

```bash
# Ephemeral development
nix develop

# Or build a pre-baked image for deployment
nix build .#image
docker load < result
distrobox create --image agentbox:latest --name dev
```

## OCI Images

### Pre-built Orchestrator Images

Each orchestrator has a pre-built image with everything included:

```bash
nix build github:farra/agentboxes#schmux-image
nix build github:farra/agentboxes#gastown-image
nix build github:farra/agentboxes#openclaw-image
nix build github:farra/agentboxes#ralph-image
```

### Project-specific Images

Build an image from your `agentbox.toml`:

```bash
nix build .#image
docker load < result
```

The image contains your orchestrator, agents, tools, and bundles - no `nix develop` needed at runtime.

### Base Image

For runtime flexibility, use the base image which includes nix with flakes:

```bash
nix build github:farra/agentboxes#base-image
```

## agentbox.toml Reference

### [orchestrator]

```toml
[orchestrator]
name = "schmux"  # schmux | gastown | openclaw | ralph
```

### [bundles]

| Bundle | Tools | Description |
|--------|-------|-------------|
| `baseline` | 28 | Modern CLI essentials (ripgrep, fd, bat, eza, jq, fzf, etc.) |
| `complete` | 61 | Everything in baseline plus git extras, networking, archives |

### [tools]

```toml
[tools]
python = "3.12"    # 3.10, 3.11, 3.12, 3.13
nodejs = "20"      # 18, 20, 22
go = "1.23"        # 1.21, 1.22, 1.23, 1.24
rust = "stable"    # stable, beta, nightly, or "1.75.0"
```

### [rust]

```toml
[rust]
components = ["rustfmt", "clippy", "rust-src", "rust-analyzer"]
```

### [llm-agents]

AI coding agents from [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix):

```toml
[llm-agents]
include = ["claude-code", "codex"]
```

Available: `claude-code`, `codex`, `gemini-cli`, `opencode`, `amp`, `goose-cli`, `aider`, and more.

### [nur]

Community packages from [NUR](https://github.com/nix-community/NUR):

```toml
[nur]
include = ["owner/package-name"]
```

## Deploying to servers

For remote deployment, build an OCI image and transfer it:

```bash
nix build .#schmux-image
docker load < result
docker save agentbox:latest | ssh server 'docker load'
```

Then run via Docker, distrobox, or any container runtime.

See the **[Deployment Guide](docs/deployment.md)** for registry publishing, team onboarding, and CI/CD examples.

## Project Structure

```
agentboxes/
├── flake.nix                 # Root flake with packages and devShells
├── lib/
│   ├── substrate.nix         # Common tools layer
│   ├── bundles.nix           # Tool bundles (baseline, complete)
│   ├── mkProjectShell.nix    # Compose devShell from agentbox.toml
│   └── mkProjectImage.nix    # Build OCI image from agentbox.toml
├── agents/                   # Agent wrappers (claude, codex, gemini, opencode)
├── orchestrators/            # Orchestrator definitions (schmux, gastown, etc.)
├── templates/project/        # Template for `nix flake init -t`
├── images/                   # OCI image definitions
└── docs/                     # Documentation
```

## Related Projects

- [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix) - Source for all agent packages
- [distrobox](https://github.com/89luca89/distrobox) - Run containers as if on host

## License

Apache-2.0
