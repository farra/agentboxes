# Gas Town

Multi-agent AI orchestration system with convoy management, persistent hooks, and work tracking via beads.

**Upstream**: https://github.com/steveyegge/gastown

## Overview

Gas Town coordinates multiple AI agents through persistent work tracking using git-backed storage. The system solves the challenge of agents losing context during restarts by maintaining state in "hooks" (git worktrees). Key concepts:

- **Mayor**: Primary AI coordinator that manages overall workflow
- **Town**: Workspace directory housing all projects and configurations
- **Rigs**: Individual project containers (git repository clones)
- **Polecats**: Ephemeral worker agents that complete tasks then terminate
- **Hooks**: Git worktree-based persistent storage surviving crashes
- **Convoys**: Work tracking bundles aggregating multiple tasks (beads)

## Quick Try

To explore gastown without setting up a project:

```bash
nix develop github:farra/agentboxes#gastown
gt install ~/gt
gt doctor
```

For other deployment options (Docker, distrobox, OCI images), see the [main README](../../README.md#how-to-run-these-environments).

## Project Setup

For real development work, create an `agentbox.toml` in your project that includes the orchestrator, language runtimes, and tools you need.

### Example: Reviewing the beads project

[beads](https://github.com/steveyegge/beads) is a Go project. To review it with gastown, you need Go available so agents can build and test the code:

```bash
git clone https://github.com/steveyegge/beads.git
cd beads
```

Create `agentbox.toml`:

```toml
[orchestrator]
name = "gastown"

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

Now you have gastown, beads (bd), Go 1.23, Claude Code, and 61 CLI tools. Agents can run `make build` and `make test`.

### Set up gastown workspace

```bash
gt install ~/gt
gt rig add beads https://github.com/steveyegge/beads.git
gt doctor
```

### Create tasks with beads

```bash
cd ~/gt/rigs/beads
bd init
bd add "Review architecture and code organization"
bd add "Analyze error handling patterns"
bd add "Assess test coverage - run 'make test'"
bd add "Document improvement recommendations"
```

### Create a convoy and start

```bash
gt convoy create --name "beads-review" --rig beads
gt mayor attach
```

The Mayor will analyze the codebase, spawn agents, and track progress. Agents have Go available, so they can actually run the build and tests.

### Monitor progress

```bash
gt convoy status beads-review
gt status
gt agents
```

## What's Included

When you use the gastown orchestrator, you get:

- **gt binary** - pre-built from GitHub releases
- **beads (bd)** - work tracking system
- **SQLite** - for convoy database queries
- **Substrate tools** - git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

Your `agentbox.toml` adds project-specific tools (Go, Python, Node.js, etc.) so agents can build and test the code.

## Configuration

### Agent Configuration

```bash
gt config agent list
gt config agent default claude
gt config agent add myagent --model claude-3-opus --flags "--verbose"
```

### Workspace Structure

After `gt install ~/gt`:

```
~/gt/
├── settings/
│   └── config.json      # Global configuration
├── rigs/
│   └── beads/           # Cloned repositories
├── hooks/               # Persistent agent state
└── convoys/             # Work tracking database
```

## CLI Reference

### Workspace Management
```bash
gt install <path>        # Create workspace
gt doctor                # Health check
gt doctor --fix          # Auto-fix common issues
gt status                # Show workspace status
```

### Rig Management
```bash
gt rig add <name> <url>  # Add repository
gt rig list              # List all rigs
gt rig remove <name>     # Remove a rig
```

### Convoy Management
```bash
gt convoy create --name <name> --rig <rig>
gt convoy add <convoy> <bead-id>
gt convoy status <convoy>
gt convoy list
```

### Agent Operations
```bash
gt mayor attach          # Launch Mayor coordinator
gt agents                # List active agents
gt sling <bead-id> <rig> # Assign work to agent
gt config agent list     # List configured agents
```

## MEOW Workflow

Gas Town emphasizes the **M**ayor-**E**nhanced **O**rchestration **W**orkflow:

1. Describe your objective to the Mayor
2. Mayor analyzes requirements and creates convoys
3. Work is tracked as beads within convoys
4. Agents are spawned and tasks distributed via hooks
5. Progress monitored through convoy status
6. Results summarized upon completion

This workflow enables scaling to 20-30+ simultaneous agents.

## Troubleshooting

### "rig not found"
Ensure the rig was added with `gt rig add` and the workspace path is correct.

### beads commands fail
Run `bd init` in the rig directory first. Ensure git is initialized.

### Agents not starting
Check `gt doctor` for configuration issues. Verify the AI runtime (claude, codex) is available in PATH.

## Links

- [Gas Town Repository](https://github.com/steveyegge/gastown)
- [Beads Repository](https://github.com/steveyegge/beads)
- [Gas Town Overview](https://github.com/steveyegge/gastown/blob/main/docs/overview.md)
- [Installation Guide](https://github.com/steveyegge/gastown/blob/main/docs/INSTALLING.md)
- [Reference Documentation](https://github.com/steveyegge/gastown/blob/main/docs/reference.md)
