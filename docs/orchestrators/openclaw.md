# OpenClaw

OpenClaw is a local-first, single-user AI agent gateway with multi-channel messaging support (WhatsApp, Telegram, Discord, Slack, Signal, iMessage).

## Quick Start

```bash
# Enter the openclaw environment
nix develop github:farra/agentboxes#openclaw

# Install openclaw via npm (one-time)
npm install -g openclaw@latest

# Run the onboarding wizard
openclaw onboard --install-daemon

# Start the gateway
openclaw gateway run
```

## What's Included

The agentboxes environment provides:

- **Node.js 22** - Required runtime (>= 22.12.0)
- **pnpm** - Package manager
- **Native build tools** - python3, pkg-config, vips, sqlite (for npm native modules)
- **Substrate tools** - git, jq, ripgrep, fd, fzf, tmux, htop, curl, rsync, and more

## Architecture

OpenClaw differs from schmux/gastown:

| Aspect | schmux/gastown | openclaw |
|--------|----------------|----------|
| Distribution | Pre-built Go binary | npm package |
| Install | Automatic via Nix | `npm install -g` in shell |
| Runtime | Self-contained | Node.js + native deps |

The agentboxes environment provides all runtime dependencies; you just need to install the openclaw package via npm.

## Key Components

- **Gateway** - WebSocket server (default: `ws://127.0.0.1:18789`) that routes messages
- **Agent** - AI agent runtime using Claude or other LLMs
- **Channels** - Integrations with messaging platforms
- **Skills** - Extensible tool system

## Common Commands

```bash
# Gateway management
openclaw gateway run              # Start gateway
openclaw gateway status           # Check status

# Messaging
openclaw message send <channel> <text>

# Configuration
openclaw config set <key> <value>
openclaw channels status --probe

# Diagnostics
openclaw doctor
```

## Links

- [OpenClaw Repository](https://github.com/openclaw/openclaw)
- [Documentation](https://docs.openclaw.ai)
