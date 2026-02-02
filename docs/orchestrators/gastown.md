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

## Installation

```bash
nix develop github:farra/agentboxes#gastown
```

For other deployment options (Docker, distrobox, OCI images), see the [main README](../../README.md#how-to-run-these-environments).

## Getting Started

```bash
# Install workspace (first-time setup)
gt install ~/gt

# Verify setup
gt doctor
gt status
```

## Example: Code Review

This walkthrough demonstrates reviewing [Yegge's beads](https://github.com/steveyegge/beads) repository.

### Step 1: Add the Repository

```bash
gt rig add beads https://github.com/steveyegge/beads.git
```

### Step 2: Initialize Beads for Task Tracking

Gas Town uses beads for work tracking. Initialize it in the beads rig:

```bash
cd ~/gt/rigs/beads
bd init

# Create beads for the code review task
bd add "Code review: Analyze architecture, code quality, and documentation"
bd add "Review error handling patterns"
bd add "Assess test coverage"
bd add "Document improvement recommendations"
```

### Step 3: Create a Convoy

Convoys group related work items:

```bash
gt convoy create --name "beads-code-review" --rig beads
gt convoy add beads-code-review <bead-id>
```

### Step 4: Launch the Mayor

The Mayor coordinates the review:

```bash
gt mayor attach
```

The Mayor will analyze the codebase, create work items as beads, spawn polecat agents, and track progress via convoys.

### Step 5: Assign Work to Agents

Use `gt sling` to assign specific beads to rigs:

```bash
gt sling <bead-id> beads
gt agents  # Monitor active agents
```

### Step 6: Monitor Progress

```bash
gt convoy status beads-code-review
gt status
gt agents
```

## Using agentbox.toml

For project-based configuration, create a `agentbox.toml`:

```toml
[orchestrator]
name = "gastown"

[bundles]
include = ["complete"]

[llm-agents]
include = ["claude-code"]
```

Then:
```bash
nix flake init -t github:farra/agentboxes#project
# Edit agentbox.toml as above
nix develop
gt install ~/gt
```

## What's Included

The agentboxes distribution provides:

- **gt binary** (v0.5.0) - pre-built from GitHub releases
- **beads (bd)** (v0.49.3) - work tracking system
- **SQLite** - for convoy database queries
- **Substrate tools** - git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

You do NOT need Go installed - the binaries are pre-built.

## Configuration

### Agent Configuration

Configure your preferred AI runtime:

```bash
# List available agents
gt config agent list

# Set default agent
gt config agent default claude

# Create custom agent alias
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
