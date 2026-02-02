# schmux

Multi-agent AI orchestration using tmux sessions.

**Upstream**: https://github.com/sergeknystautas/schmux

## Overview

schmux creates isolated workspaces (git clones) for each agent session, running them in separate tmux sessions. This allows multiple AI agents to work on the same codebase simultaneously without conflicts. A web dashboard at `http://localhost:7337` provides real-time monitoring and session management.

## Quick Try

To explore schmux without setting up a project:

```bash
nix develop github:farra/agentboxes#schmux
schmux start
open http://localhost:7337
```

For other deployment options (Docker, distrobox, OCI images), see the [main README](../../README.md#how-to-run-these-environments).

## Project Setup

For real development work, create an `agentbox.toml` in your project that includes the orchestrator, language runtimes, and tools you need.

### Example: Reviewing the beads project

[beads](https://github.com/steveyegge/beads) is a Go project that needs Go for building/testing. Here's how to set up an environment for reviewing it with schmux:

```bash
git clone https://github.com/steveyegge/beads.git
cd beads
```

Create `agentbox.toml`:

```toml
[orchestrator]
name = "schmux"

[bundles]
include = ["complete"]

[tools]
go = "1.23"  # beads is written in Go

[llm-agents]
include = ["claude-code"]
```

Initialize and enter the environment:

```bash
nix flake init -t github:farra/agentboxes#project
nix develop
```

Now you have schmux, Go 1.23, Claude Code, and 61 CLI tools available. The agent can actually build and test the code, not just read it.

### Configure schmux

Create `~/.schmux/config.json`:

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
  "terminal": {
    "width": 120,
    "height": 40,
    "seed_lines": 100
  }
}
```

### Start the review

```bash
schmux start
schmux spawn -t claude -r beads -p "Review this Go codebase. Run 'make test' to verify tests pass, then analyze code quality, error handling, and test coverage."
```

The agent has Go available, so it can run `make build`, `make test`, and understand the actual behavior—not just static analysis.

### Monitor progress

```bash
schmux list          # Show active sessions
schmux attach <id>   # Attach to tmux session
```

Or use the dashboard at `http://localhost:7337`.

## What's Included

When you use the schmux orchestrator, you get:

- **schmux binary** - pre-built from GitHub releases
- **Dashboard** - React web UI for monitoring sessions
- **Substrate tools** - git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

Your `agentbox.toml` adds project-specific tools (Go, Python, Node.js, etc.) so agents can build and test the code.

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
Run from within `nix develop` or ensure the binary wrapper is used.

## Links

- [schmux Repository](https://github.com/sergeknystautas/schmux)
- [CLI Reference](https://github.com/sergeknystautas/schmux/blob/main/docs/cli.md)
- [Configuration Guide](https://github.com/sergeknystautas/schmux/blob/main/docs/config-migration.md)
- [Targets Documentation](https://github.com/sergeknystautas/schmux/blob/main/docs/targets.md)
