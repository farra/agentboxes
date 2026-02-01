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

The user already has [cautomaton-develops](https://github.com/farra/cautomaton-develops) which provides the foundation pattern: `deps.toml` → Nix flake → devShell. This project extends that pattern to a multi-environment monorepo.

## Target Environments

### Orchestrators (multi-agent systems)

| Name | Language | Key Deps | Repo |
|------|----------|----------|------|
| schmux | Go 1.24 | tmux, nodejs, git | Local (friend's project) |
| gastown | Go 1.23 | tmux, beads, sqlite, git | github.com/steveyegge/gastown |
| crewai | Python 3.12 | uv | github.com/crewAIInc/crewAI |
| maestro | TypeScript | nodejs, electron | github.com/pedramamini/Maestro (desktop app, less suitable for server) |

### Individual Agents

| Name | Language | Key Deps |
|------|----------|----------|
| claude | Node.js | Claude Code CLI |
| aider | Python | aider-chat package |
| opencode | Go | opencode CLI |

## Architecture

### Directory Structure

```
agentboxes/
├── flake.nix                    # Root flake with all outputs
├── lib/
│   └── mkDevShell.nix           # Shared logic from cautomaton-develops
├── agents/
│   ├── claude/
│   │   ├── flake.nix            # Standalone (works independently)
│   │   └── deps.toml
│   ├── aider/
│   └── opencode/
├── orchestrators/
│   ├── schmux/
│   │   ├── flake.nix
│   │   ├── deps.toml
│   │   └── README.md
│   ├── gastown/
│   └── crewai/
├── distrobox.ini                # Team manifest
└── scripts/
    ├── build-images.sh          # Build all OCI images
    └── publish.sh               # Push to ghcr.io
```

### Root flake.nix Structure

```nix
{
  outputs = { self, nixpkgs, rust-overlay }: {
    # Templates for `nix flake init -t`
    templates = {
      schmux = { path = ./orchestrators/schmux; description = "..."; };
      claude = { path = ./agents/claude; description = "..."; };
      # ...
    };

    # DevShells for `nix develop`
    devShells = forAllSystems (system: {
      schmux = mkDevShell system ./orchestrators/schmux/deps.toml {};
      claude = mkDevShell system ./agents/claude/deps.toml {};
      # ...
    });

    # OCI images for `nix build .#<name>-image`
    packages = forAllSystems (system: {
      schmux-image = mkImage "schmux" [ go nodejs tmux ];
      # ...
    });
  };
}
```

### deps.toml Format (from cautomaton-develops)

```toml
[bundles]
include = ["complete"]  # or ["baseline"]

[tools]
go = "1.24"
python = "3.12"
nodejs = "20"
rust = "stable"

[rust]
components = ["rustfmt", "clippy"]
```

The `mkDevShell.nix` reads this and resolves packages from nixpkgs.

## Build & Test Commands

```bash
# Enter a devShell
nix develop .#schmux

# Build an OCI image
nix build .#schmux-image
docker load < result

# Build all images
./scripts/build-images.sh

# Publish to registry
./scripts/publish.sh
```

## Key Design Decisions

1. **Each orchestrator/agent has a standalone flake.nix** - Can be used independently or via the root flake
2. **deps.toml is the user-facing config** - Matches cautomaton-develops pattern
3. **OCI images built from same Nix definitions** - Single source of truth
4. **distrobox.ini for non-Nix users** - Lower barrier to entry

## Implementation Priority

1. **Phase 1**: Set up root flake.nix with template/devShell structure
2. **Phase 2**: Port mkDevShell.nix from cautomaton-develops
3. **Phase 3**: Add schmux and claude as first environments
4. **Phase 4**: Add OCI image building
5. **Phase 5**: Add remaining orchestrators/agents
6. **Phase 6**: CI/CD for auto-publishing images

## Reference: cautomaton-develops flake.nix

The user's existing project at `~/dev/me/cautomaton-develops` has the core pattern. Key files:

- `template/flake.nix` - Full devShell implementation with tool bundles, version mapping
- `template/deps.toml` - Example config format
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
