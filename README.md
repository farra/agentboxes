# agentboxes

Ready-to-run environments for AI coding agents and orchestrators.

Try locally, deploy to EC2, or run via distrobox. One command.

## Quick Start

```bash
# Enter the schmux environment
nix develop github:farra/agentboxes#schmux

# Start the orchestrator
schmux start
schmux status  # Opens dashboard at http://localhost:7337
```

## What This Is

**agentboxes** provides reproducible Nix-based development environments for:

1. **Individual AI Agents** - Claude Code, Codex CLI, Gemini CLI, OpenCode
2. **Agent Orchestrators** - Schmux, Gastown, Ralph Wiggum, OpenClaw

Each environment includes all necessary dependencies (language runtimes, tools, CLI utilities) so you can evaluate and run these tools without polluting your system.

## Why

- **No system pollution** - Everything runs in isolated Nix shells
- **Reproducible** - Same environment on any machine via `flake.lock`
- **Multiple deployment targets** - Local dev, EC2 instances, distrobox containers
- **Easy comparison** - Try multiple orchestrators side-by-side

## Available Environments

### Substrate (Common Tools)

All environments include the **substrate layer** - a curated set of tools for development workflows:

```bash
# Use substrate directly for a minimal environment
nix develop github:farra/agentboxes#substrate
```

Includes: git, curl, wget, jq, yq, ripgrep, fd, fzf, tree, less, file, openssh, rsync, tmux, htop

### Orchestrators

| Name | Description | Status | Command |
|------|-------------|--------|---------|
| `schmux` | Multi-agent tmux orchestrator | Available | `nix develop .#schmux` |
| `gastown` | Multi-agent convoy orchestrator | Available | `nix develop .#gastown` |
| `openclaw` | Multi-channel AI gateway | Available | `nix develop .#openclaw` |
| `ralph` | Ralph Wiggum autonomous Claude runner | Available | `nix develop .#ralph` |

### Agents

| Name | Description | Status | Command |
|------|-------------|--------|---------|
| `claude` | Claude Code CLI | Available | `nix develop .#claude` |
| `codex` | OpenAI Codex CLI | Available | `nix develop .#codex` |
| `gemini` | Google Gemini CLI | Planned | - |
| `opencode` | OpenCode CLI | Planned | - |

See [docs/orchestrators/](docs/orchestrators/) for detailed guides.

## Usage Patterns

### Project Template (Recommended)

Create a self-contained project with orchestrator + agents + runtimes defined in `deps.toml`:

```bash
# Initialize a new project
mkdir my-ai-project && cd my-ai-project
nix flake init -t github:farra/agentboxes#project

# Edit deps.toml to configure your environment
cat deps.toml
# [orchestrator]
# name = "schmux"
# [agents]
# claude = true
# [runtimes]
# python = "3.12"

# Enter the composed environment
nix develop
```

### Local Development

```bash
# Enter environment interactively
nix develop github:farra/agentboxes#schmux

# Or with direnv (auto-activate)
echo "use flake github:farra/agentboxes#schmux" > .envrc
direnv allow
```

### Build Package Locally

```bash
# Build the package
nix build github:farra/agentboxes#schmux

# Run directly
./result/bin/schmux version
```

### Container Images

```bash
# Build the base image (includes substrate tools)
nix build github:farra/agentboxes#base-image

# Load into Docker
docker load < result

# Run interactively
docker run -it agentboxes-base:latest

# Use with distrobox
distrobox create --image agentboxes-base:latest --name agentbox
distrobox enter agentbox
```

## Project Structure

```
agentboxes/
├── flake.nix                 # Root flake with packages and devShells
├── lib/
│   ├── substrate.nix         # Common tools layer
│   ├── bundles.nix           # Tool bundles (baseline, complete)
│   └── mkProjectShell.nix    # Compose devShell from deps.toml
├── agents/
│   ├── claude/
│   │   └── default.nix       # Claude Code wrapper
│   └── codex/
│       └── default.nix       # Codex CLI wrapper
├── orchestrators/
│   ├── schmux/
│   │   └── default.nix       # schmux package definition
│   ├── gastown/
│   │   └── default.nix       # gastown package definition
│   ├── openclaw/
│   │   └── default.nix       # openclaw environment
│   └── ralph/
│       └── default.nix       # ralph wrapper scripts
├── templates/
│   └── project/
│       ├── flake.nix         # Template flake that reads deps.toml
│       └── deps.toml         # Example configuration
├── images/
│   └── base.nix              # Base OCI image definition
├── docs/
│   └── orchestrators/
│       ├── schmux.md         # Usage guide
│       ├── gastown.md        # Usage guide
│       ├── openclaw.md       # Usage guide
│       └── ralph.md          # Usage guide
└── vendor/                   # Git submodules for reference
    ├── schmux/
    ├── gastown/
    └── openclaw/
```

## Server Deployment (EC2/Cloud)

These environments are designed to run on remote servers:

- **Recommended**: Single EC2 instance per orchestrator (t3.large for 3-6 concurrent agents)
- **Alternative**: Single VM with distrobox isolation between orchestrators
- **Access**: Tailscale or similar for secure private access

See [docs/deployment.md](docs/deployment.md) for detailed cloud deployment guides.

## Related Projects

- [cautomaton-develops](https://github.com/farra/cautomaton-develops) - The foundation this builds on
- [dev-agent-backlog](https://github.com/farra/dev-agent-backlog) - Org-mode based agent work tracking

## License

Apache-2.0
