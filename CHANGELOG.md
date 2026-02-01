# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Substrate layer** (`lib/substrate.nix`) - Common tools shared across all environments: git, curl, wget, jq, yq-go, ripgrep, fd, fzf, tree, less, file, openssh, rsync, tmux, htop, which
- **Base OCI image** (`images/base.nix`) - Minimal container image with substrate tools, suitable for distrobox or direct deployment
- `devShells.substrate` - Direct access to substrate tools without an orchestrator
- `packages.base-image` - Build the base OCI image with `nix build .#base-image`
- **Gastown orchestrator** (`orchestrators/gastown/`) - Multi-agent convoy orchestrator (v0.5.0) with beads (v0.49.3)
- `devShells.gastown` - Gastown environment with gt, beads, sqlite, and substrate tools
- `packages.gastown` - Build gastown binary standalone
- `packages.beads` - Build beads (bd) binary standalone
- **OpenClaw orchestrator** (`orchestrators/openclaw/`) - Multi-channel AI gateway environment
- `devShells.openclaw` - OpenClaw environment with Node.js 22, pnpm, native build tools, and substrate
- **Claude agent** (`agents/claude/`) - Claude Code CLI via claude-code-nix flake
- `devShells.claude` - Standalone Claude Code environment with substrate tools
- `packages.claude` - Build Claude Code package standalone
- **Codex agent** (`agents/codex/`) - OpenAI Codex CLI via codex-cli-nix flake
- `devShells.codex` - Standalone Codex CLI environment with substrate tools
- `packages.codex` - Build Codex CLI package standalone
- **Tool bundles** (`lib/bundles.nix`) - Baseline (28 tools) and complete (61 tools) bundles from cautomaton-develops
- **mkProjectShell** (`lib/mkProjectShell.nix`) - Compose devShell from deps.toml configuration
- **Project template** (`templates/project/`) - `nix flake init -t .#project` scaffolds a deps.toml-based environment
- **Design doc 002** - Composable Agent Environments architecture

### Changed

- schmux environment now composes with substrate layer (inherits all substrate tools)

### Fixed

### Removed
