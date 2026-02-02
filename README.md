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

### Option B: Deploy persistently (distrobox)

```bash
# Build and load the base image
nix build github:farra/agentboxes#base-image
docker load < result

# Create a persistent container
distrobox create --image agentboxes-base:latest --name dev
distrobox enter dev

# Inside distrobox: install your orchestrator
nix develop github:farra/agentboxes#schmux
schmux start
```

Your orchestrator state (tmux sessions, config files, workspaces) survives restarts. Distrobox shares your `$HOME`, so SSH keys and dotfiles just work.

### When to use which

| Scenario | Approach |
|----------|----------|
| Trying an orchestrator | `nix develop` |
| Comparing orchestrators side-by-side | `nix develop` |
| Running on a remote server | distrobox |
| Long-running orchestrator with state | distrobox |
| Team environment on shared VM | distrobox (one per team member) |

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
nix develop
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
│  │  distrobox: dev                           │  │
│  │  └── nix develop .#schmux                 │  │
│  │      └── schmux daemon + tmux sessions    │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

**Sizing**: t3.large (2 vCPU, 8GB) handles 3-6 concurrent agents. Memory-bound, not CPU-bound.

**Access**: Use Tailscale for secure private access to dashboards (schmux: `:7337`, etc.)

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
│   └── mkProjectShell.nix    # Compose devShell from agentbox.toml
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
