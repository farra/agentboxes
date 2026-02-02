# CLAUDE.md

## Project Overview

**agentboxes** is a Nix flake monorepo providing reproducible development environments for AI coding agents and multi-agent orchestrators. Users can:

1. `nix develop github:farra/agentboxes#<name>` - Enter a ready-to-use environment
2. `nix flake init -t github:farra/agentboxes#<name>` - Scaffold a new project
3. `nix build .#<name>-image` - Build OCI container images for deployment
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
| claude | Node.js | Claude Code CLI (via claude-code-nix) | Available |
| codex | Rust | Codex CLI (via codex-cli-nix) | Available |
| gemini | Go | Google Gemini CLI | Planned |
| opencode | Go | OpenCode CLI | Planned |

## Architecture

### Directory Structure

```
agentboxes/
├── flake.nix                    # Root flake with all outputs
├── lib/
│   ├── substrate.nix            # Common tools layer (git, jq, rg, etc.)
│   ├── bundles.nix              # Tool bundles (baseline: 28, complete: 61)
│   ├── mkProjectShell.nix       # Compose devShell from agentbox.toml
│   ├── mkProjectImage.nix       # Build baked OCI images
│   ├── mkSlimImage.nix          # Build slim bootstrap images
│   └── mkProfilePackage.nix     # Build env for nix profile install
├── agents/
│   ├── claude/
│   │   └── default.nix          # Wrapper for claude-code-nix flake
│   └── codex/
│       └── default.nix          # Wrapper for codex-cli-nix flake
├── orchestrators/
│   ├── schmux/
│   │   └── default.nix          # Schmux package + shell
│   ├── gastown/
│   │   └── default.nix          # Gastown package + shell
│   └── openclaw/
│       └── default.nix          # OpenClaw environment
├── templates/
│   └── project/
│       ├── flake.nix            # Template that reads agentbox.toml
│       └── agentbox.toml        # Example configuration
├── images/
│   └── base.nix                 # Base OCI image definition
└── docs/
    └── orchestrators/           # Usage guides
```

### Root flake.nix Structure

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Agent flakes (community-maintained, fast-updating)
    claude-code.url = "github:sadjow/claude-code-nix";
    codex-cli.url = "github:sadjow/codex-cli-nix";
  };

  outputs = { self, nixpkgs, flake-utils, claude-code, codex-cli }: {
    # Templates for `nix flake init -t`
    templates.project = { path = ./templates/project; description = "..."; };

    # Library functions for downstream projects
    lib.mkProjectOutputs = configPath: /* reads agentbox.toml, returns devShells */;

    # DevShells for `nix develop`
    devShells = forAllSystems (system: {
      substrate = /* common tools only */;
      schmux = /* orchestrator + substrate */;
      gastown = /* orchestrator + substrate */;
      openclaw = /* orchestrator + substrate */;
      claude = /* agent + substrate */;
      codex = /* agent + substrate */;
    });

    # Packages for `nix build`
    packages = forAllSystems (system: {
      schmux = /* schmux binary */;
      gastown = /* gastown binary */;
      claude = /* claude-code package */;
      codex = /* codex-cli package */;
      base-image = /* OCI image with substrate */;
    });
  };
}
```

### agentbox.toml Format

Project environments are configured via `agentbox.toml`:

```toml
# Image configuration (for OCI image builds)
[image]
name = "my-project"
base = "wolfi"        # wolfi (smaller) or nix (fully reproducible)
tag = "latest"
variant = "slim"      # "slim" (default) or "baked"
auto_bootstrap = true # Run bootstrap on first shell (default: true, slim only)

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
- OCI image building with slim/baked variants

The `mkProjectShell.nix` reads this and composes a devShell with substrate + orchestrator + agents + bundles + packages.

### OCI Image Variants

Three image variants are available for each orchestrator:

| Variant | Size | First Boot | Reproducibility | Use Case |
|---------|------|------------|-----------------|----------|
| **slim** (default) | ~300MB | Runs `just bootstrap` | wolfi base | Development, CI |
| **baked** | ~500MB-2GB | Ready immediately | wolfi base | Production, slow networks |
| **full** | ~11GB | Ready immediately | Pure Nix | Air-gapped, reproducibility |

**Slim images** (default) ship bootstrap tooling (nix, just, direnv) and install the full environment on first boot via `nix profile install`. This makes images small and fast to pull, with first-boot setup taking a few minutes.

**Baked images** pre-install all tools in the image. Larger to pull but ready to use immediately.

**Full images** use a pure Nix base (no wolfi) for complete reproducibility. Very large but fully deterministic.

```bash
# Build slim image (default)
nix build .#schmux-image

# Build baked image
nix build .#schmux-baked-image

# Build full Nix image
nix build .#schmux-full-image

# Build profile package (for nix profile install)
nix build .#schmux-env
```

**Slim image workflow:**
1. `distrobox create --image schmux:latest --name dev`
2. `distrobox enter dev`
3. Auto-bootstrap runs on first shell (or run `just bootstrap`)
4. Tools are installed to `~/.nix-profile`, persisted across sessions
5. Update later with `just update`

## Build & Test Commands

```bash
# Enter orchestrator shells
nix develop .#schmux
nix develop .#gastown
nix develop .#openclaw

# Enter agent shells
nix develop .#claude
nix develop .#codex

# Create a new project from template
mkdir my-project && cd my-project
nix flake init -t .#project
# Edit agentbox.toml, then:
nix develop

# Build packages
nix build .#schmux
nix build .#claude

# Build OCI images (slim is default)
nix build .#schmux-image          # Slim bootstrap image
nix build .#schmux-baked-image    # Baked wolfi image
nix build .#schmux-full-image     # Pure Nix image
docker load < result

# Build profile packages (for nix profile install)
nix build .#schmux-env

# Validate flake
nix flake check
```

## Key Design Decisions

1. **Each orchestrator/agent has a standalone flake.nix** - Can be used independently or via the root flake
2. **agentbox.toml is the user-facing config** - Simple TOML configuration for environments
3. **OCI images built from same Nix definitions** - Single source of truth
4. **distrobox.ini for non-Nix users** - Lower barrier to entry
5. **External dependencies via flake inputs** - Community best practice; all orchestrators/agents fetch from upstream (GitHub releases, npm, or flake inputs)
6. **vendor/ is for REFERENCE ONLY** - The `vendor/` submodules exist for local development reference and reading upstream code. Nix definitions NEVER use vendor/ directly; they always fetch from upstream sources

## Implementation Status

1. **Phase 1**: Set up root flake.nix with template/devShell structure - DONE
2. **Phase 2**: Create substrate layer and mkProjectShell - DONE
3. **Phase 3**: Add schmux, gastown, openclaw orchestrators - DONE
4. **Phase 4**: Add claude and codex agents via external flakes - DONE
5. **Phase 5**: Create project template with agentbox.toml composition - DONE
6. **Phase 6**: Add OCI image building from agentbox.toml - IN PROGRESS
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
