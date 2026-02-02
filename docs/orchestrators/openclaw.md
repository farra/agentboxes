# OpenClaw

Local-first, single-user AI agent gateway with multi-channel messaging support.

**Upstream**: https://github.com/The-Grit-Agencies/OpenClaw

## Overview

OpenClaw is a **messaging gateway** that routes conversations from various platforms (WhatsApp, Telegram, Discord, Slack, Signal, iMessage) to AI agents. Unlike schmux or gastown which orchestrate multiple agents working on code, OpenClaw focuses on being a personal AI assistant accessible through your preferred messaging apps.

**Note**: OpenClaw is best suited for conversational AI tasks rather than autonomous code reviews. For dedicated code review workflows, consider [schmux](schmux.md) or [gastown](gastown.md) instead.

## Getting Started: Code Analysis via Chat

While OpenClaw isn't designed for autonomous code orchestration, you can use it to interact with AI agents for code-related questions and analysis via messaging. This walkthrough shows how to set up OpenClaw and use it for code discussions about [Yegge's beads](https://github.com/steveyegge/beads).

### Option A: Using Nix (Recommended)

```bash
# Enter the openclaw environment
nix develop github:farra/agentboxes#openclaw

# Run the onboarding wizard
openclaw onboard --install-daemon

# Start the gateway
openclaw gateway run
```

### Option B: Using Docker

```bash
# Build and load the base image
nix build github:farra/agentboxes#base-image
docker load < result

# Run with port exposure for gateway
docker run -it \
  -v ~/.config/openclaw:/root/.config/openclaw \
  -p 18789:18789 \
  agentboxes-base:latest

# Inside container
nix develop github:farra/agentboxes#openclaw
openclaw onboard --install-daemon
openclaw gateway run
```

### Option C: Using Distrobox

```bash
# Build the base image
nix build github:farra/agentboxes#base-image
docker load < result

# Create and enter distrobox
distrobox create --image agentboxes-base:latest --name openclaw-box
distrobox enter openclaw-box

# Set up openclaw
nix develop github:farra/agentboxes#openclaw
openclaw onboard --install-daemon
openclaw gateway run
```

## Configuring for Code Discussions

### Step 1: Complete Onboarding

The onboarding wizard configures:
- AI provider (Claude, OpenAI, etc.)
- Messaging channel integrations
- Gateway settings

```bash
openclaw onboard --install-daemon
```

### Step 2: Configure a Channel

Connect your preferred messaging platform:

```bash
# Check available channels
openclaw channels status --probe

# Configure a channel (e.g., Telegram)
openclaw config set telegram.bot_token "YOUR_BOT_TOKEN"
```

### Step 3: Clone the Repository Locally

Since OpenClaw doesn't manage workspaces like schmux, clone the repo you want to discuss:

```bash
git clone https://github.com/steveyegge/beads.git ~/projects/beads
```

### Step 4: Start the Gateway

```bash
openclaw gateway run
```

### Step 5: Chat About Code

Through your connected messaging app, you can now:
- Ask questions about the beads codebase
- Request code explanations
- Discuss architecture decisions
- Get suggestions for improvements

Example conversation:
```
You: Can you explain the architecture of the beads project at ~/projects/beads?

AI: [Analyzes the codebase and provides explanation]

You: What patterns does it use for error handling?

AI: [Provides analysis of error handling patterns]
```

## Using agentbox.toml

For project-based configuration:

```toml
[orchestrator]
name = "openclaw"

[bundles]
include = ["complete"]

[tools]
nodejs = "22"

[llm-agents]
include = ["claude-code"]
```

Then:
```bash
nix flake init -t github:farra/agentboxes#project
# Edit agentbox.toml as above
nix develop
openclaw onboard --install-daemon
```

## What's Included

The agentboxes environment provides:

- **Node.js 22** - Required runtime (>= 22.12.0)
- **pnpm** - Package manager
- **Native build tools** - python3, pkg-config, vips, sqlite
- **Substrate tools** - git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

## Architecture

OpenClaw differs from code-focused orchestrators:

| Aspect | schmux/gastown | openclaw |
|--------|----------------|----------|
| Purpose | Multi-agent code orchestration | Messaging gateway |
| Workflow | Autonomous task execution | Conversational Q&A |
| Repository management | Clones/manages workspaces | User manages locally |
| Best for | Code reviews, refactoring | Chat-based assistance |

### Key Components

- **Gateway** - WebSocket server (default: `ws://127.0.0.1:18789`) routing messages
- **Agent** - AI runtime using Claude or other LLMs
- **Channels** - Platform integrations (WhatsApp, Telegram, etc.)
- **Skills** - Extensible tool system for agent capabilities

## CLI Reference

### Gateway Management
```bash
openclaw gateway run              # Start gateway
openclaw gateway status           # Check status
openclaw gateway stop             # Stop gateway
```

### Messaging
```bash
openclaw message send <channel> "<text>"
openclaw message list <channel>
```

### Configuration
```bash
openclaw config set <key> <value>
openclaw config get <key>
openclaw channels status --probe
```

### Diagnostics
```bash
openclaw doctor                   # Health check
openclaw onboard --install-daemon # Re-run setup
```

## When to Use OpenClaw

**Good fit:**
- Personal AI assistant via messaging apps
- Quick code questions while on mobile
- Chat-based project discussions
- Integration with existing messaging workflows

**Consider alternatives:**
- For autonomous multi-agent code reviews: use [schmux](schmux.md)
- For convoy-based work orchestration: use [gastown](gastown.md)
- For autonomous single-agent loops: use [ralph](ralph.md)

## Troubleshooting

### Gateway fails to start
Check port 18789 availability and Node.js version:
```bash
node --version  # Should be >= 22.12.0
lsof -i :18789  # Check if port is in use
```

### Channel connection issues
Verify credentials and run diagnostics:
```bash
openclaw doctor
openclaw channels status --probe
```

### Agent not responding
Ensure AI provider credentials are configured:
```bash
openclaw config get anthropic.api_key
```

## Links

- [OpenClaw Repository](https://github.com/The-Grit-Agencies/OpenClaw)
- [OpenClaw Documentation](https://docs.openclaw.ai)
