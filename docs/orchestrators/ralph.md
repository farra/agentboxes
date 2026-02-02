# Ralph Wiggum

Bash-based autonomous development loop for Claude Code with intelligent exit detection, rate limiting, and circuit breaker patterns.

**Upstream**: https://github.com/frankbria/ralph-claude-code

## Overview

Ralph enables continuous autonomous development by running Claude Code in a loop with built-in safeguards against infinite loops and API overuse. Named after Geoffrey Huntley's technique for autonomous Claude operation, Ralph:

- Runs Claude Code repeatedly until tasks are complete
- Detects completion through intelligent pattern matching
- Implements rate limiting (configurable calls/hour)
- Uses circuit breakers to detect stagnation
- Provides a live monitoring dashboard via tmux

Unlike multi-agent orchestrators (schmux, gastown), Ralph focuses on a single Claude agent working autonomously on a project.

## Quick Try

To explore ralph without setting up a project:

```bash
nix develop github:farra/agentboxes#ralph
ralph-enable
ralph --monitor
```

For other deployment options (Docker, distrobox, OCI images), see the [main README](../../README.md#how-to-run-these-environments).

## Project Setup

For real development work, create an `agentbox.toml` in your project that includes the orchestrator, language runtimes, and tools you need.

### Example: Reviewing the beads project

[beads](https://github.com/steveyegge/beads) is a Go project. To review it with ralph, you need Go available so Claude can build and test the code:

```bash
git clone https://github.com/steveyegge/beads.git
cd beads
```

Create `agentbox.toml`:

```toml
[orchestrator]
name = "ralph"

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

Now you have ralph, Go 1.23, Claude Code, and 61 CLI tools. Claude can run `make build` and `make test`.

### Enable ralph

```bash
ralph-enable
```

The wizard detects the project type and creates `.ralph/` configuration.

### Configure the review task

Edit `.ralph/PROMPT.md`:

```markdown
# Code Review: Beads Project

## Objective
Review this Go codebase for quality, architecture, and test coverage.

## Instructions
1. Run `make test` to verify tests pass
2. Analyze code organization and error handling
3. Check test coverage with `go test -cover ./...`
4. Create REVIEW.md with findings

## Constraints
- Do not modify source code
- Focus on analysis and documentation
```

Edit `.ralph/fix_plan.md`:

```markdown
# Review Tasks

- [ ] Run make test and verify all tests pass
- [ ] Review main package structure
- [ ] Analyze error handling patterns
- [ ] Assess test coverage
- [ ] Document findings in REVIEW.md
```

### Start the review

```bash
ralph --monitor
```

Claude has Go available, so it can actually run the build and tests—not just static analysis.

### Monitor progress

The dashboard shows iteration count, API calls remaining, and circuit breaker status.

```bash
ralph --status
ralph --circuit-status
```

## What's Included

When you use the ralph orchestrator, you get:

- **Claude Code** - Automatically included (Ralph requires it)
- **ralph** - Main autonomous loop command
- **ralph-monitor** - Live terminal dashboard
- **ralph-enable** - Interactive project setup wizard
- **Substrate tools** - git, jq, ripgrep, fd, fzf, tmux, and more

Your `agentbox.toml` adds project-specific tools (Go, Python, Node.js, etc.) so Claude can build and test the code.

## Project Structure

After `ralph-enable`, your project has:

```
your-project/
├── .ralph/
│   ├── PROMPT.md      # High-level instructions for Claude
│   ├── fix_plan.md    # Prioritized task checklist
│   ├── AGENT.md       # Build/run commands (auto-maintained)
│   ├── .ralphrc       # Project configuration
│   ├── specs/         # Detailed specifications
│   ├── logs/          # Execution logs
│   └── status.json    # Real-time loop status
└── src/               # Your source code
```

| File | Purpose | Edit? |
|------|---------|-------|
| `PROMPT.md` | Project goals and principles | Yes |
| `fix_plan.md` | Task checklist | Yes |
| `AGENT.md` | Build/test commands | Rarely |
| `.ralphrc` | Configuration | Rarely |

## CLI Reference

### Project Setup
```bash
ralph-enable                    # Interactive wizard
ralph-enable --from beads       # Import tasks from beads
ralph-enable --from github      # Import from GitHub issues
ralph-enable --skip-tasks       # Skip task import
```

### Running the Loop
```bash
ralph --monitor                 # Start with tmux dashboard
ralph                           # Start without monitoring
ralph --calls 50                # Limit to 50 API calls/hour
ralph --timeout 30              # 30-minute timeout per iteration
ralph --live                    # Show Claude output in real-time
```

### Status and Control
```bash
ralph --status                  # Show current status
ralph --circuit-status          # Show circuit breaker state
ralph --reset-circuit           # Reset circuit breaker
ralph --reset-session           # Clear session state
```

## Exit Detection

Ralph uses intelligent exit detection to stop the loop:

1. **Completion Indicators** - Pattern matching in Claude's output
2. **EXIT_SIGNAL** - Explicit signal from Claude in RALPH_STATUS block
3. **Circuit Breaker** - Detects stagnation (no file changes, repeated errors)
4. **Rate Limiting** - Configurable calls per hour (default: 100)

Both conditions must be met to exit:
- `completion_indicators >= 2` (pattern-based detection)
- `EXIT_SIGNAL: true` (Claude's explicit confirmation)

This prevents premature exits from false positives.

## Architecture Comparison

| Aspect | schmux/gastown | ralph |
|--------|----------------|-------|
| Agent model | Multi-agent | Single-agent (Claude) |
| Coordination | Daemon + dashboard | Bash loop + tmux |
| Task tracking | External (beads/convoys) | Internal (fix_plan.md) |
| Best for | Parallel workstreams | Focused autonomous work |

## Troubleshooting

### Loop exits immediately
Check PROMPT.md and fix_plan.md are properly configured:
```bash
cat .ralph/PROMPT.md
cat .ralph/fix_plan.md
```

### Circuit breaker trips
The circuit breaker activates on repeated failures or stagnation:
```bash
ralph --circuit-status
ralph --reset-circuit
```

### Claude not responding
Ensure Claude Code is available and authenticated:
```bash
claude --version
claude "hello"
```

### Rate limit reached
Adjust the calls-per-hour limit:
```bash
ralph --calls 100
```

## Links

- [Ralph Repository](https://github.com/frankbria/ralph-claude-code)
- [Ralph CLAUDE.md](https://github.com/frankbria/ralph-claude-code/blob/main/CLAUDE.md) - Detailed documentation
