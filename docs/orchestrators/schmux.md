# schmux

Multi-agent AI orchestration using tmux sessions.

**Upstream**: https://github.com/sergeknystautas/schmux

## Overview

schmux creates isolated workspaces (git clones) for each agent session, running them in separate tmux sessions. This allows multiple AI agents to work on the same codebase simultaneously without conflicts. A web dashboard at `http://localhost:7337` provides real-time monitoring and session management.

## Getting Started: Code Review Example

This walkthrough demonstrates reviewing [Yegge's beads](https://github.com/steveyegge/beads) repository using schmux.

### Option A: Using Nix (Recommended)

```bash
# Enter the schmux environment
nix develop github:farra/agentboxes#schmux

# Start the daemon (first run creates config interactively)
schmux start

# Open the dashboard
open http://localhost:7337  # or browse manually
```

On first run, schmux guides you through configuration. When prompted:
1. Accept the default workspace directory (`~/schmux-workspaces`) or specify another
2. Add the beads repository when prompted for repos

### Option B: Using Docker

```bash
# Build and load the base image
nix build github:farra/agentboxes#base-image
docker load < result

# Run interactively with volume mounts for persistence
docker run -it \
  -v ~/.schmux:/root/.schmux \
  -v ~/schmux-workspaces:/root/schmux-workspaces \
  -p 7337:7337 \
  agentboxes-base:latest

# Inside the container, install schmux and start
curl -fsSL https://raw.githubusercontent.com/sergeknystautas/schmux/main/install.sh | bash
schmux start
```

### Option C: Using Distrobox

```bash
# Build the base image
nix build github:farra/agentboxes#base-image
docker load < result

# Create and enter distrobox container
distrobox create --image agentboxes-base:latest --name schmux-box
distrobox enter schmux-box

# Inside distrobox, install and run
curl -fsSL https://raw.githubusercontent.com/sergeknystautas/schmux/main/install.sh | bash
schmux start
```

## Configuring for Beads Code Review

### Step 1: Create Configuration

If not created during first run, create `~/.schmux/config.json`:

```json
{
  "workspace_path": "~/schmux-workspaces",
  "repos": [
    {
      "name": "beads",
      "url": "https://github.com/steveyegge/beads.git"
    }
  ],
  "run_targets": [
    {
      "name": "claude",
      "type": "detected",
      "command": "claude"
    }
  ],
  "quick_launch": [],
  "terminal": {
    "width": 120,
    "height": 40,
    "seed_lines": 100
  }
}
```

### Step 2: Start the Daemon

```bash
schmux start
schmux status  # Verify running, shows dashboard URL
```

### Step 3: Spawn a Code Review Agent

Via CLI:
```bash
schmux spawn -t claude -r beads -p "Review this codebase for code quality, architecture, and potential improvements. Focus on: 1) Code organization 2) Error handling 3) Testing coverage 4) Documentation quality"
```

Or via the web dashboard at `http://localhost:7337`:
1. Click "New Session"
2. Select repository: `beads`
3. Select target: `claude`
4. Enter prompt for code review task
5. Click "Spawn"

### Step 4: Monitor Progress

```bash
schmux list          # Show active sessions
schmux attach <id>   # Attach to tmux session to watch
```

Or use the dashboard's real-time terminal streaming.

## Using deps.toml

For project-based configuration, create a `deps.toml`:

```toml
[orchestrator]
name = "schmux"

[bundles]
include = ["complete"]

[llm-agents]
include = ["claude-code"]
```

Then:
```bash
nix flake init -t github:farra/agentboxes#project
# Edit deps.toml as above
nix develop
schmux start
```

## What's Included

The agentboxes distribution provides:

- **schmux binary** (v1.1.1) - pre-built from GitHub releases
- **Dashboard assets** - React web UI for monitoring sessions
- **Substrate tools** - git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

You do NOT need Go or Node.js installed - the binary is pre-built.

## CLI Reference

### Daemon Management
```bash
schmux start          # Start daemon in background
schmux stop           # Stop daemon
schmux status         # Show status and dashboard URL
schmux daemon-run     # Run in foreground (for debugging)
```

### Session Management
```bash
schmux spawn -t <target> -p "<prompt>" [flags]
schmux list           # List active sessions
schmux attach <id>    # Attach to tmux session
schmux dispose <id>   # Clean up a session
```

### Spawn Flags
- `-t, --target` - Run target (required)
- `-p, --prompt` - Task prompt
- `-r, --repo` - Repository name from config
- `-b, --branch` - Branch (default: main)
- `-w, --workspace` - Explicit workspace path
- `-n, --nickname` - Session label
- `--json` - JSON output for automation

## Architecture

```
┌─────────────────────────────────────────┐
│  schmux daemon (:7337)                  │
├─────────────────────────────────────────┤
│  Session 1: claude on feature-branch    │
│  Session 2: codex on bugfix-branch      │
│  Session 3: claude on refactor-branch   │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│  ~/schmux-workspaces/                   │
│  ├── workspace-001/  (clone 1)          │
│  ├── workspace-002/  (clone 2)          │
│  └── workspace-003/  (clone 3)          │
└─────────────────────────────────────────┘
```

Key concepts:
- **Workspace**: Isolated git clone where an agent works
- **Run Target**: AI coding tool (claude, codex, etc.) or custom command
- **Session**: tmux session running a target in a workspace
- **Overlays**: Auto-copy files (`.env`, configs) into workspaces

## Troubleshooting

### "daemon is not running" after start
```bash
cat ~/.schmux/daemon.log
```
Common causes: invalid config.json, missing `terminal` block, port 7337 in use.

### Dashboard shows 404 for assets
Ensure you're using the packaged binary, not a separately installed one.

### tmux not found
Run from within `nix develop .#schmux` or ensure the binary wrapper is used.

## Links

- [schmux Repository](https://github.com/sergeknystautas/schmux)
- [CLI Reference](https://github.com/sergeknystautas/schmux/blob/main/docs/cli.md)
- [Configuration Guide](https://github.com/sergeknystautas/schmux/blob/main/docs/config-migration.md)
- [Targets Documentation](https://github.com/sergeknystautas/schmux/blob/main/docs/targets.md)
