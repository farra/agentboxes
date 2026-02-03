# CLAUDE.md

## Project Overview

**agentboxes** is a Nix flake monorepo providing reproducible development environments for AI coding agents and multi-agent orchestrators. Users can:

1. `nix develop github:farra/agentboxes#<name>` - Enter a ready-to-use environment
2. `nix flake init -t github:farra/agentboxes#<name>` - Scaffold a new project
3. `just build-image <name>` - Build OCI container images for deployment
4. Use `distrobox.ini` for team onboarding

## Background Context

This project emerged from exploring how to run multi-agent orchestrators (like schmux) in cloud environments. Key findings:

- **Orchestrators are single-machine, stateful apps** - They don't fit K8s well (tmux sessions, file-based state)
- **Best deployment**: EC2/VM per orchestrator, or single VM with distrobox isolation
- **EC2 sizing**: t3.large (2 vCPU, 8GB) handles 3-6 concurrent agents; memory-bound, not CPU-bound

The user already has [cautomaton-develops](https://github.com/farra/cautomaton-develops) which provides the foundation pattern for Nix devShells. This project uses `agentbox.toml` as its configuration format, extending that pattern to a multi-environment monorepo.

## Target Environments

### Orchestrators (multi-agent systems)

| Name | Language | Key Deps | Repo |
|------|----------|----------|------|
| schmux | Go 1.24 | tmux, nodejs, git | Local (friend's project) |
| gastown | Go 1.23 | tmux, beads, sqlite, git | github.com/steveyegge/gastown |
| openclaw | TypeScript | nodejs, pnpm | github.com/The-Grit-Agencies/OpenClaw |
| ralph | Python | claude-code | Ralph Wiggum autonomous Claude runner |

### Individual Agents

| Name | Language | Key Deps | Status |
|------|----------|----------|--------|
| claude | Node.js | Claude Code CLI (via llm-agents.nix) | Available |
| codex | Rust | Codex CLI (via llm-agents.nix) | Available |
| gemini | Go | Google Gemini CLI | Available |
| opencode | Go | OpenCode CLI | Available |

## Architecture

### Directory Structure

```
agentboxes/
├── flake.nix                    # Root flake with all outputs
├── justfile                     # Build commands for images, testing, dev
├── lib/
│   ├── substrate.nix            # Common tools layer (git, jq, rg, etc.)
│   ├── bundles.nix              # Tool bundles (baseline: 28, complete: 61)
│   ├── parseAgentboxConfig.nix  # Shared TOML parsing logic
│   ├── mkProjectShell.nix       # Compose devShell from agentbox.toml
│   └── mkProfilePackage.nix     # Build env for nix profile install
├── agents/
│   ├── claude/
│   │   └── default.nix          # Wrapper for claude-code
│   ├── codex/
│   │   └── default.nix          # Wrapper for codex
│   ├── gemini/
│   │   └── default.nix          # Wrapper for gemini-cli
│   └── opencode/
│       └── default.nix          # Wrapper for opencode
├── orchestrators/
│   ├── schmux/
│   │   └── default.nix          # Schmux package + shell
│   ├── gastown/
│   │   └── default.nix          # Gastown package + shell
│   ├── openclaw/
│   │   └── default.nix          # OpenClaw environment
│   └── ralph/
│       └── default.nix          # Ralph environment
├── templates/
│   └── project/
│       ├── flake.nix            # Template that reads agentbox.toml
│       └── agentbox.toml        # Example configuration
├── images/
│   └── Containerfile            # OCI image builder
├── distros/
│   └── *.toml                   # Pre-configured orchestrator configs
└── docs/
    └── orchestrators/           # Usage guides
```

### Data Flow

```
                    agentbox.toml
                         │
                         ▼
               ┌─────────────────────┐
               │ parseAgentboxConfig │  (shared Nix logic)
               └─────────────────────┘
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼
┌──────────────────┐          ┌──────────────────┐
│  mkProjectShell  │          │ mkProfilePackage │
│  → devShell      │          │  → *-env package │
└──────────────────┘          └──────────────────┘
                                        │
                                        ▼
                              ┌──────────────────┐
                              │   Containerfile  │
                              │  nix profile     │
                              │  install .#*-env │
                              └──────────────────┘
                                        │
                                        ▼
                              ┌──────────────────┐
                              │   OCI Image      │
                              └──────────────────┘
```

### agentbox.toml Format

Project environments are configured via `agentbox.toml`:

```toml
# Image configuration
[image]
name = "my-project"
tag = "latest"
base = "wolfi"

# Orchestrator (optional) - agentboxes-specific
[orchestrator]
name = "schmux"   # schmux | gastown | openclaw | ralph

# AI coding agents from llm-agents.nix
agents = ["claude-code"]
# Available: claude-code, codex, gemini-cli, opencode, amp, goose-cli, aider, etc.

# Predefined tool bundles
bundles = ["baseline", "rust-stable"]
# Available:
# - baseline: Modern CLI essentials (ripgrep, fd, bat, jq, etc.)
# - complete: Full dev environment (baseline + more)
# - rust-stable: Rust stable toolchain with rustfmt and clippy
# - rust-nightly: Rust nightly toolchain
# - rust-beta: Rust beta toolchain

# Exact nixpkgs package names (use `nix search nixpkgs <name>`)
# NUR packages use "nur:owner/package" prefix
packages = [
  "python312",
  "nodejs_22",
  "go_1_24",
  # "nur:owner/package",
]
```

**agentbox.toml features:**
- `[orchestrator]` section - multi-agent coordinators
- `agents` list - AI coding agents from numtide/llm-agents.nix
- `bundles` list - predefined tool collections and rust toolchains
- `packages` list - exact nixpkgs names (no version mapping magic)
- NUR packages via `nur:owner/package` prefix
- Pre-built devShells (`nix develop .#schmux`, `.#claude`, etc.)

The `mkProjectShell.nix` reads this and composes a devShell with substrate + orchestrator + agents + bundles + packages.

### OCI Image Building

Images are built using a Containerfile that installs the `-env` profile package:

```bash
# Build an image
just build-image schmux

# Or manually:
podman build --build-arg ENV_NAME=schmux -t agentboxes-schmux images/
```

The Containerfile:
1. Starts from `wolfi-toolbox` base (distrobox-compatible)
2. Installs Nix using Determinate Systems installer
3. Runs `nix profile install .#<name>-env` to bake all tools

Images are ready to use immediately with distrobox:
```bash
distrobox create --image ghcr.io/farra/agentboxes-schmux:latest --name dev
distrobox enter dev
```

## Build & Test Commands

```bash
# Enter orchestrator shells
nix develop .#schmux
nix develop .#gastown
nix develop .#openclaw
nix develop .#ralph

# Enter agent shells
nix develop .#claude
nix develop .#codex
nix develop .#gemini
nix develop .#opencode

# Create a new project from template
mkdir my-project && cd my-project
nix flake init -t github:farra/agentboxes#project
# Edit agentbox.toml, then:
nix develop

# Build packages
nix build .#schmux
nix build .#claude

# Build profile packages (for nix profile install)
nix build .#schmux-env

# Build OCI images (via justfile)
just build-image schmux
just build-image gastown

# Test locally with distrobox
just test-local schmux

# Release to registry
just release schmux v1.0.0

# Validate flake
just check
# or: nix flake check
```

## Key Design Decisions

1. **Each orchestrator/agent has a standalone flake.nix** - Can be used independently or via the root flake
2. **agentbox.toml is the user-facing config** - Simple TOML configuration for environments
3. **Containerfile-based image building** - Uses `nix profile install` for baked images
4. **distrobox.ini for non-Nix users** - Lower barrier to entry
5. **External dependencies via flake inputs** - Community best practice; all orchestrators/agents fetch from upstream (GitHub releases, npm, or flake inputs)
6. **vendor/ is for REFERENCE ONLY** - The `vendor/` submodules exist for local development reference and reading upstream code. Nix definitions NEVER use vendor/ directly; they always fetch from upstream sources

## Implementation Status

1. **Phase 1**: Set up root flake.nix with template/devShell structure - DONE
2. **Phase 2**: Create substrate layer and mkProjectShell - DONE
3. **Phase 3**: Add schmux, gastown, openclaw, ralph orchestrators - DONE
4. **Phase 4**: Add claude, codex, gemini, opencode agents via llm-agents.nix - DONE
5. **Phase 5**: Create project template with agentbox.toml composition - DONE
6. **Phase 6**: Add Containerfile-based OCI image building - DONE
7. **Phase 7**: CI/CD for auto-publishing images - PLANNED

## Reference: cautomaton-develops flake.nix

The user's existing project at `~/dev/me/cautomaton-develops` has the core pattern. Key files:

- `template/flake.nix` - Full devShell implementation with tool bundles, version mapping
- `template/deps.toml` - Example config format (note: agentboxes uses `agentbox.toml`)
- Root `flake.nix` - Just defines `templates.default`

The implementation includes:
- Tool bundles: `baseline` (28 tools), `complete` (58 tools)
- Version mapping for python, nodejs, go, rust
- Rust toolchain via rust-overlay with components support
- Cross-platform support (x86_64-linux, aarch64-linux, aarch64-darwin, x86_64-darwin)

## Notes for Development

- User is familiar with Nix flakes and devbox
- User prefers practical, working code over extensive documentation
- The "cautomaton" namespace is for personal projects; this repo is more community-oriented
- Consider Universal Blue / uCore / bootc for base OS if deploying to cloud (user explored this)
- Maestro is an Electron desktop app - may not fit server deployment model

## Related User Projects

- `~/dev/me/cautomaton-develops` - Foundation pattern to build from
- `~/dev/me/dev-agent-backlog` - Org-mode agent work tracking (Claude Code plugin)

## Design Doc Workflow

This project uses design docs for task management. Design docs live in `docs/design/`.

### Key Files
- `backlog.org` - Working surface for active tasks
- `docs/design/*.org` - Design documents (source of truth)
- `README.org` - Project config (prefix, categories, statuses)

### Workflow
1. Create design docs with `/backlog:new-design-doc`
2. Queue tasks with `/backlog:task-queue <id>`
3. Start work with `/backlog:task-start <id>`
4. Complete with `/backlog:task-complete <id>`

### Task ID Format
`[AB-NNN-XX]` where:
- AB = project prefix
- NNN = design doc number
- XX = task sequence
