# agentboxes

Ready-to-run environments for AI coding agents and orchestrators.

Try locally, deploy to EC2, or run via distrobox. One command.

## Quick Start

```bash
# Enter an orchestrator environment
nix develop github:farra/agentboxes#schmux

# Or just an agent
nix develop github:farra/agentboxes#claude
```

## Available Environments

### Orchestrators

| Name | Description | Command |
|------|-------------|---------|
| `schmux` | Multi-agent tmux orchestrator | `nix develop .#schmux` |
| `gastown` | Multi-agent convoy orchestrator | `nix develop .#gastown` |
| `openclaw` | Multi-channel AI gateway | `nix develop .#openclaw` |
| `ralph` | Ralph Wiggum autonomous Claude runner | `nix develop .#ralph` |

### Agents

| Name | Description | Command |
|------|-------------|---------|
| `claude` | Claude Code CLI | `nix develop .#claude` |
| `codex` | OpenAI Codex CLI | `nix develop .#codex` |
| `gemini` | Google Gemini CLI | `nix develop .#gemini` |
| `opencode` | OpenCode CLI | `nix develop .#opencode` |

### Substrate (Common Tools)

All environments include the **substrate layer** - git, curl, jq, ripgrep, fd, fzf, tmux, htop, and more.

```bash
# Use substrate directly for a minimal environment
nix develop github:farra/agentboxes#substrate
```

## Creating a Project

The recommended way to use agentboxes is to create a project with a `deps.toml` file:

```bash
mkdir my-ai-project && cd my-ai-project
nix flake init -t github:farra/agentboxes#project
```

This creates a `flake.nix` and `deps.toml`. Edit `deps.toml` to configure your environment:

```toml
# Orchestrator (optional) - multi-agent coordinator
[orchestrator]
name = "schmux"

# Tool bundles: "baseline" (28 tools) or "complete" (61 tools)
[bundles]
include = ["complete"]

# Language runtimes
[tools]
python = "3.12"
nodejs = "20"
# go = "1.23"
# rust = "stable"  # or "beta", "nightly", "1.75.0"

# Rust components (when rust is enabled)
# [rust]
# components = ["rustfmt", "clippy", "rust-src", "rust-analyzer"]

# AI coding agents
[llm-agents]
include = ["claude-code"]
# Available: claude-code, codex, gemini-cli, opencode, amp, goose-cli, aider

# NUR packages (format: "owner/package")
# [nur]
# include = []
```

Then enter the environment:

```bash
nix develop
```

## deps.toml Reference

### [orchestrator]

Optional. Adds a multi-agent orchestrator to your environment.

```toml
[orchestrator]
name = "schmux"  # schmux | gastown | openclaw | ralph
```

### [bundles]

Pre-configured tool collections:

| Bundle | Tools | Description |
|--------|-------|-------------|
| `baseline` | 28 | Modern CLI essentials (ripgrep, fd, bat, eza, jq, fzf, etc.) |
| `complete` | 61 | Everything in baseline plus git extras, networking, archives, etc. |

```toml
[bundles]
include = ["complete"]
```

### [tools]

Language runtimes with version pinning:

```toml
[tools]
python = "3.12"    # 3.10, 3.11, 3.12, 3.13
nodejs = "20"      # 18, 20, 22
go = "1.23"        # 1.21, 1.22, 1.23, 1.24
rust = "stable"    # stable, beta, nightly, or "1.75.0"
```

### [rust]

Rust toolchain components (only used when `rust` is in `[tools]`):

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

## Other Usage Patterns

### Direct Shell Access

```bash
# Enter environment interactively
nix develop github:farra/agentboxes#schmux

# With direnv (auto-activate on cd)
echo "use flake github:farra/agentboxes#schmux" > .envrc
direnv allow
```

### Build Packages

```bash
nix build github:farra/agentboxes#schmux
./result/bin/schmux version
```

### Container Images

```bash
# Build the base image (includes substrate tools)
nix build github:farra/agentboxes#base-image
docker load < result

# Run interactively
docker run -it agentboxes-base:latest

# Use with distrobox
distrobox create --image agentboxes-base:latest --name agentbox
distrobox enter agentbox
```

## Orchestrator Guides

- [schmux](docs/orchestrators/schmux.md) - tmux-based multi-agent orchestrator
- [gastown](docs/orchestrators/gastown.md) - convoy-style orchestrator
- [openclaw](docs/orchestrators/openclaw.md) - multi-channel AI gateway
- [ralph](docs/orchestrators/ralph.md) - autonomous Claude Code runner

## Server Deployment

These environments work well on remote servers:

- **Recommended**: Single EC2 instance per orchestrator (t3.large handles 3-6 concurrent agents)
- **Alternative**: Single VM with distrobox isolation between orchestrators
- **Access**: Tailscale or similar for secure private access

## Why agentboxes?

- **No system pollution** - Everything runs in isolated Nix shells
- **Reproducible** - Same environment on any machine via `flake.lock`
- **Multiple deployment targets** - Local dev, EC2 instances, distrobox containers
- **Easy comparison** - Try multiple orchestrators side-by-side

## Project Structure

```
agentboxes/
├── flake.nix                 # Root flake with packages and devShells
├── lib/
│   ├── substrate.nix         # Common tools layer
│   ├── bundles.nix           # Tool bundles (baseline, complete)
│   └── mkProjectShell.nix    # Compose devShell from deps.toml
├── agents/                   # Agent wrappers (claude, codex, gemini, opencode)
├── orchestrators/            # Orchestrator definitions (schmux, gastown, etc.)
├── templates/project/        # Template for `nix flake init -t`
├── images/                   # OCI image definitions
└── docs/                     # Documentation
```

## Related Projects

- [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix) - Source for all agent packages
- [cautomaton-develops](https://github.com/farra/cautomaton-develops) - Foundation this builds on

## License

Apache-2.0
