# agentboxes

Reproducible environments for AI coding agents and orchestrators.

**Try locally** with `nix develop`. **Deploy persistently** with distrobox.

## Quick Start

### Option A: Try it out (ephemeral)

```bash
nix develop github:farra/agentboxes#schmux
schmux start
```

The environment disappears when you exit. Great for exploration.

### Option B: Deploy persistently (pre-built image + distrobox)

```bash
# Build a pre-built orchestrator image (everything baked in)
nix build github:farra/agentboxes#schmux-image
docker load < result

# Create a persistent container
distrobox create --image agentbox:latest --name schmux-box
distrobox enter schmux-box

# Just works - no nix develop needed!
schmux start
```

Your orchestrator state (tmux sessions, config files, workspaces) survives restarts. Distrobox shares your `$HOME`, so SSH keys and dotfiles just work.

### Option C: Deploy with runtime flexibility (base image + nix develop)

```bash
# Build the base image (includes nix with flakes)
nix build github:farra/agentboxes#base-image
docker load < result

# Create a persistent container
distrobox create --image agentboxes-base:latest --name dev
distrobox enter dev

# Install any orchestrator at runtime
nix develop github:farra/agentboxes#schmux
schmux start
```

Use this when you want to switch between orchestrators or need runtime flexibility.

### When to use which

| Scenario | Approach |
|----------|----------|
| Trying an orchestrator | `nix develop` (Option A) |
| Comparing orchestrators side-by-side | `nix develop` (Option A) |
| Production deployment | Pre-built image + distrobox (Option B) |
| Long-running orchestrator with state | Pre-built image + distrobox (Option B) |
| Need to switch orchestrators at runtime | Base image + distrobox (Option C) |
| Team environment on shared VM | Pre-built images (one distrobox per member) |

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

## Server Deployment

Orchestrators are stateful apps (tmux sessions, daemon processes). They work best with persistent environments:

```
┌─────────────────────────────────────────────────┐
│  EC2 / VM                                       │
│  ┌───────────────────────────────────────────┐  │
│  │  distrobox: schmux-box                    │  │
│  │  └── schmux (pre-installed via image)     │  │
│  │      └── schmux daemon + tmux sessions    │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

Build and deploy:
```bash
nix build .#schmux-image
docker load < result
docker save agentbox:latest | ssh server 'docker load'
ssh server 'distrobox create --image agentbox:latest --name schmux-box'
```

**Sizing**: t3.large (2 vCPU, 8GB) handles 3-6 concurrent agents. Memory-bound, not CPU-bound.

**Access**: Use Tailscale for secure private access to dashboards (schmux: `:7337`, etc.)

See the **[Deployment Guide](docs/deployment.md)** for:
- Publishing images to container registries (ghcr.io, Docker Hub)
- Team onboarding with distrobox.ini
- CI/CD workflows for automated image builds
- Multi-orchestrator server setups

## Why agentboxes?

- **Reproducible** - Same environment anywhere via `flake.lock`
- **No system pollution** - Everything in isolated Nix shells
- **Persistent when needed** - distrobox for long-running orchestrators
- **Batteries included** - 61 modern CLI tools in the substrate layer

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
