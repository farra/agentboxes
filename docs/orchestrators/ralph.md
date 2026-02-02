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

## Getting Started: Code Review Example

This walkthrough demonstrates using Ralph to review [Yegge's beads](https://github.com/steveyegge/beads) repository.

### Option A: Using Nix (Recommended)

```bash
# Clone the repository to review
git clone https://github.com/steveyegge/beads.git
cd beads

# Enter the ralph environment
nix develop github:farra/agentboxes#ralph

# Enable Ralph in this project (interactive wizard)
ralph-enable

# Start the autonomous loop with monitoring
ralph --monitor
```

### Option B: Using Docker

```bash
# Clone the repository
git clone https://github.com/steveyegge/beads.git
cd beads

# Build and load the base image
nix build github:farra/agentboxes#base-image
docker load < result

# Run with project mounted
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  agentboxes-base:latest

# Inside container
nix develop github:farra/agentboxes#ralph
ralph-enable
ralph --monitor
```

### Option C: Using Distrobox

```bash
# Clone the repository
git clone https://github.com/steveyegge/beads.git
cd beads

# Build the base image
nix build github:farra/agentboxes#base-image
docker load < result

# Create and enter distrobox
distrobox create --image agentboxes-base:latest --name ralph-box
distrobox enter ralph-box

# Navigate to project and set up
cd /path/to/beads
nix develop github:farra/agentboxes#ralph
ralph-enable
ralph --monitor
```

## Configuring for Code Review

### Step 1: Enable Ralph (Interactive)

The `ralph-enable` wizard auto-detects your project and creates configuration:

```bash
cd beads
ralph-enable
```

The wizard will:
1. Detect project type (Go in this case)
2. Identify available task sources (GitHub issues, beads, PRD files)
3. Create the `.ralph/` configuration directory
4. Generate initial configuration files

### Step 2: Configure PROMPT.md

Edit `.ralph/PROMPT.md` to describe the code review task:

```markdown
# Code Review: Beads Project

## Objective
Perform a comprehensive code review of this Go-based distributed issue tracker.

## Focus Areas
1. **Architecture**: Evaluate the overall design and modularity
2. **Code Quality**: Identify code smells, duplication, and style issues
3. **Error Handling**: Review error handling patterns and consistency
4. **Testing**: Assess test coverage and test quality
5. **Documentation**: Evaluate inline comments and README quality

## Deliverables
- Create a REVIEW.md file with findings organized by category
- Prioritize issues by severity (critical, major, minor)
- Include specific file:line references for each finding
- Suggest concrete improvements where applicable

## Constraints
- Do not modify source code files
- Focus on analysis and documentation only
- Complete the review in a single session
```

### Step 3: Configure fix_plan.md

Edit `.ralph/fix_plan.md` to list specific review tasks:

```markdown
# Code Review Tasks

## High Priority
- [ ] Review main package structure and entry points
- [ ] Analyze error handling patterns across the codebase
- [ ] Assess test coverage and identify gaps

## Medium Priority
- [ ] Review Go idioms and best practices usage
- [ ] Check for potential race conditions
- [ ] Evaluate logging and observability

## Low Priority
- [ ] Review documentation completeness
- [ ] Check dependency management
- [ ] Assess build and CI configuration

## Completed
```

### Step 4: Start the Review

```bash
# Start with monitoring dashboard (recommended)
ralph --monitor

# Or without dashboard
ralph

# With custom settings
ralph --calls 50 --timeout 30 --live
```

### Step 5: Monitor Progress

The dashboard shows:
- Current iteration number
- API calls remaining
- Circuit breaker status
- Recent Claude output

```bash
# In a separate terminal
ralph-monitor

# Or check status
ralph --status
ralph --circuit-status
```

## Using agentbox.toml

For project-based configuration:

```toml
[orchestrator]
name = "ralph"

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
ralph-enable
```

## What's Included

The agentboxes environment provides:

- **Claude Code** - Automatically included (Ralph requires it)
- **ralph** - Main autonomous loop command
- **ralph-monitor** - Live terminal dashboard
- **ralph-enable** - Interactive project setup wizard
- **Runtime deps** - bash, jq, git, tmux, coreutils, grep, sed, awk
- **Substrate tools** - ripgrep, fd, fzf, htop, curl, rsync, and more

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

### Key Files

| File | Purpose | Edit? |
|------|---------|-------|
| `PROMPT.md` | Project goals and principles | Yes - customize |
| `fix_plan.md` | Task checklist | Yes - add tasks |
| `AGENT.md` | Build/test commands | Rarely - auto-maintained |
| `.ralphrc` | Configuration | Rarely - sensible defaults |

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
ralph --monitor                 # Start with tmux dashboard (recommended)
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

### Monitoring
```bash
ralph-monitor                   # Launch status dashboard
```

## Exit Detection

Ralph uses intelligent exit detection to stop the loop:

1. **Completion Indicators** - Pattern matching in Claude's output
2. **EXIT_SIGNAL** - Explicit signal from Claude in RALPH_STATUS block
3. **Circuit Breaker** - Detects stagnation (no file changes, repeated errors)
4. **Rate Limiting** - Configurable calls per hour (default: 100)

### Dual-Condition Verification

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
ralph --calls 100  # Increase limit
```

## Links

- [Ralph Repository](https://github.com/frankbria/ralph-claude-code)
- [Ralph CLAUDE.md](https://github.com/frankbria/ralph-claude-code/blob/main/CLAUDE.md) - Detailed documentation
