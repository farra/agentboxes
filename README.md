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

1. **Individual AI Agents** - Claude Code, Aider, OpenCode, Codex CLI
2. **Agent Orchestrators** - Schmux, Gastown, CrewAI, and others

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
| `gastown` | Multi-agent workspace manager | Planned | - |
| `crewai` | Role-playing agent framework | Planned | - |

### Agents

| Name | Description | Status | Command |
|------|-------------|--------|---------|
| `claude` | Claude Code CLI | Planned | - |
| `aider` | Aider AI pair programming | Planned | - |
| `opencode` | OpenCode CLI | Planned | - |

See [docs/orchestrators/](docs/orchestrators/) for detailed guides.

## Usage Patterns

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
│   └── substrate.nix         # Common tools layer
├── images/
│   └── base.nix              # Base OCI image definition
├── orchestrators/
│   └── schmux/
│       └── default.nix       # schmux package definition
├── docs/
│   └── orchestrators/
│       └── schmux.md         # Usage guide
└── vendor/                   # Git submodules for reference
    └── schmux/
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

MIT
