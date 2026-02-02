# Ralph Wiggum

Ralph is a bash-based autonomous development loop for Claude Code. It runs Claude Code repeatedly with intelligent exit detection, rate limiting, and circuit breaker patterns to enable continuous autonomous development.

## Quick Start

```bash
# Enter the ralph environment
nix develop github:farra/agentboxes#ralph

# Enable Ralph in your project
cd your-project
ralph-enable

# Start the autonomous loop with monitoring dashboard
ralph --monitor
```

## What's Included

The agentboxes environment provides:

- **Claude Code** - Automatically included (ralph requires it)
- **ralph** - Main autonomous loop command
- **ralph-monitor** - Live terminal dashboard for tracking loop status
- **ralph-enable** - Interactive wizard to enable Ralph in existing projects
- **Runtime deps** - bash, jq, git, tmux, coreutils, grep, sed, awk
- **Substrate tools** - ripgrep, fd, fzf, htop, curl, rsync, and more

## Architecture

Ralph differs from other orchestrators:

| Aspect | schmux/gastown | openclaw | ralph |
|--------|----------------|----------|-------|
| Distribution | Pre-built Go binary | npm package | Bash scripts |
| Agent model | Multi-agent | Gateway/router | Single-agent (Claude) |
| Install | Bundled in Nix | Auto-installed via npm | Wrapped scripts from source |
| Agent requirement | Bring your own | Configurable | Always Claude Code |

## Key Components

- **ralph_loop.sh** - Main autonomous loop with rate limiting and exit detection
- **ralph_monitor.sh** - Live tmux dashboard showing loop status
- **ralph_enable.sh** - Project setup wizard with task import
- **lib/** - Modular components (circuit breaker, response analyzer, date utils)

## Project Structure

Ralph creates a `.ralph/` directory in your project:

```
your-project/
├── .ralph/
│   ├── PROMPT.md      # Main development instructions
│   ├── fix_plan.md    # Prioritized task list
│   ├── AGENT.md       # Build/run instructions
│   ├── .ralphrc       # Project configuration
│   ├── logs/          # Execution logs
│   └── status.json    # Real-time status
└── src/               # Your source code
```

## Common Commands

```bash
# Project setup
ralph-enable                    # Interactive wizard
ralph-enable --from beads       # Import tasks from beads
ralph-enable --from github      # Import from GitHub issues
ralph-enable --skip-tasks       # Skip task import

# Running the loop
ralph --monitor                 # Start with tmux dashboard (recommended)
ralph                           # Start without monitoring
ralph --calls 50                # Limit to 50 API calls/hour
ralph --timeout 30              # Set 30-minute timeout per iteration
ralph --live                    # Show Claude output in real-time

# Status and control
ralph --status                  # Show current status
ralph --circuit-status          # Show circuit breaker state
ralph --reset-circuit           # Reset circuit breaker
ralph --reset-session           # Clear session state

# Monitoring (separate terminal)
ralph-monitor                   # Launch status dashboard
```

## Exit Detection

Ralph uses intelligent exit detection to stop the loop:

- **Completion indicators** - Natural language pattern matching
- **EXIT_SIGNAL** - Explicit signal from Claude in RALPH_STATUS block
- **Circuit breaker** - Detects stagnation (no file changes, repeated errors)
- **Rate limiting** - Configurable calls per hour (default: 100)

## Links

- [Ralph Repository](https://github.com/frankbria/ralph-claude-code)
- [Ralph CLAUDE.md](https://github.com/frankbria/ralph-claude-code/blob/main/CLAUDE.md) - Detailed documentation
