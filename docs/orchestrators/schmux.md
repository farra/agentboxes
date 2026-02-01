# schmux

Multi-agent AI orchestration using tmux sessions.

**Upstream**: https://github.com/sergeknystautas/schmux

## Quick Start

```bash
# Enter the schmux environment
nix develop github:farra/agentboxes#schmux

# Start the daemon
schmux start

# Open the dashboard
schmux status  # Shows URL (default: http://localhost:7337)

# Stop the daemon
schmux stop
```

## What's Included

The agentboxes distribution provides:

- **schmux binary** (v1.1.1) - pre-built from GitHub releases
- **Dashboard assets** - React web UI for monitoring sessions
- **Substrate tools** - Common utilities: git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

You do NOT need Go or Node.js installed - the binary is pre-built.

## Configuration

schmux requires a config file at `~/.schmux/config.json`. This is user-specific and defines your repositories, agents, and workspace settings.

### Minimal Config

Create `~/.schmux/config.json`:

```json
{
  "workspace_path": "~/schmux-workspaces",
  "repos": [],
  "run_targets": [],
  "quick_launch": [],
  "terminal": {
    "width": 120,
    "height": 40,
    "seed_lines": 100
  }
}
```

### Adding Repositories

```json
{
  "repos": [
    {
      "name": "my-project",
      "url": "git@github.com:user/my-project.git"
    }
  ]
}
```

### Full Configuration

See upstream documentation for complete config options:
- [schmux Configuration Guide](https://github.com/sergeknystautas/schmux/blob/main/docs/config-migration.md)
- [CLI Reference](https://github.com/sergeknystautas/schmux/blob/main/docs/cli.md)

## Usage

### Basic Commands

```bash
schmux start          # Start daemon in background
schmux stop           # Stop daemon
schmux status         # Show status and dashboard URL
schmux list           # List active sessions
schmux spawn          # Create a new agent session (interactive)
schmux attach <id>    # Attach to a tmux session
schmux dispose <id>   # Clean up a session
```

### Dashboard

The web dashboard at http://localhost:7337 provides:
- Real-time session monitoring
- Terminal output streaming
- Spawn wizard for creating sessions
- Diff viewer for workspace changes

## How It Works

schmux creates isolated workspaces (git clones) for each agent session, running them in separate tmux sessions. This allows multiple AI agents to work on the same codebase simultaneously without conflicts.

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

## Building Locally

If you've cloned agentboxes:

```bash
# Build the package
nix build .#schmux

# Run directly
./result/bin/schmux version

# Enter dev shell
nix develop .#schmux
```

## Troubleshooting

### "daemon is not running" after start

Check the daemon log:
```bash
cat ~/.schmux/daemon.log
```

Common issues:
- Invalid config.json format
- Missing `terminal` configuration block
- Port 7337 already in use

### Dashboard shows 404 for assets

The agentboxes distribution includes dashboard assets. If you see 404s, ensure you're using the packaged binary, not a separately installed one.

### tmux not found

The nix environment includes tmux. Make sure you're running from within `nix develop .#schmux` or using the packaged binary at `./result/bin/schmux`.
