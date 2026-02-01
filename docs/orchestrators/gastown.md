# Gas Town

Gas Town is a multi-agent AI orchestration system with convoy management, persistent hooks, and work tracking via beads.

## Quick Start

```bash
# Enter the gastown environment
nix develop github:farra/agentboxes#gastown

# Run gastown
gt --help
```

## What's Included

The agentboxes distribution provides:

- **gt binary** (v0.5.0) - pre-built from GitHub releases
- **beads (bd)** (v0.49.3) - work tracking system dependency
- **SQLite** - for convoy database queries
- **Substrate tools** - Common utilities: git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

You do NOT need Go installed - the binaries are pre-built.

## Requirements

Gas Town requires an AI coding runtime. Supported options:
- Claude Code CLI (default)
- Codex CLI
- Cursor, Gemini, and others

Configure your runtime per project in `settings/config.json`.

## Building Standalone

```bash
# Build just the gt binary
nix build github:farra/agentboxes#gastown
./result/bin/gt --help

# Build just the beads binary
nix build github:farra/agentboxes#beads
./result/bin/bd --help
```

## Links

- [Gas Town Repository](https://github.com/steveyegge/gastown)
- [Beads Repository](https://github.com/steveyegge/beads)
