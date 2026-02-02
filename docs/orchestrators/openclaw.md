# OpenClaw

Local-first, single-user AI agent gateway with multi-channel messaging support.

**Upstream**: https://github.com/The-Grit-Agencies/OpenClaw

## Overview

OpenClaw is a **messaging gateway** that routes conversations from various platforms (WhatsApp, Telegram, Discord, Slack, Signal, iMessage) to AI agents. Unlike schmux or gastown which orchestrate multiple agents working on code, OpenClaw focuses on being a personal AI assistant accessible through your preferred messaging apps.

**Note**: OpenClaw is best suited for conversational AI tasks rather than autonomous code reviews. For dedicated code review workflows, consider [schmux](schmux.md) or [gastown](gastown.md) instead.

## Quick Try

To explore openclaw without setting up a project:

```bash
nix develop github:farra/agentboxes#openclaw
openclaw onboard --install-daemon
openclaw gateway run
```

For other deployment options (Docker, distrobox, OCI images), see the [main README](../../README.md#how-to-run-these-environments).

## Project Setup

For a project where you want OpenClaw available for chat-based assistance, create an `agentbox.toml` that includes the gateway and any tools your project needs.

### Example: TypeScript project with chat support

If you're working on a TypeScript project and want to chat about it via messaging:

```bash
cd my-typescript-project
```

Create `agentbox.toml`:

```toml
[orchestrator]
name = "openclaw"

[bundles]
include = ["complete"]

[tools]
nodejs = "22"  # OpenClaw requires Node.js 22+

[llm-agents]
include = ["claude-code"]
```

Initialize and enter the environment:

```bash
nix flake init -t github:farra/agentboxes#project
nix develop
```

Now you have OpenClaw, Node.js 22, Claude Code, and 61 CLI tools.

### Set up the gateway

```bash
openclaw onboard --install-daemon
openclaw gateway run
```

### Configure a messaging channel

```bash
openclaw channels status --probe
openclaw config set telegram.bot_token "YOUR_BOT_TOKEN"
```

Now you can chat about your project via Telegram, ask questions about the code, or get help with development—all from your phone.

## What's Included

When you use the openclaw orchestrator, you get:

- **Node.js 22** - Required runtime (>= 22.12.0)
- **pnpm** - Package manager
- **Native build tools** - python3, pkg-config, vips, sqlite
- **Substrate tools** - git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

Your `agentbox.toml` can add additional tools for your specific project.

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
