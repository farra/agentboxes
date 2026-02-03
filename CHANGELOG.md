# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **justfile** - Build commands for image building, registry operations, distrobox testing, and development workflows
- **parseAgentboxConfig.nix** (`lib/parseAgentboxConfig.nix`) - Shared TOML parsing logic extracted from mkProjectShell and mkProfilePackage
- **Substrate layer** (`lib/substrate.nix`) - Common tools shared across all environments: git, curl, wget, jq, yq-go, ripgrep, fd, fzf, tree, less, file, openssh, rsync, tmux, htop, which
- `devShells.substrate` - Direct access to substrate tools without an orchestrator
- **Gastown orchestrator** (`orchestrators/gastown/`) - Multi-agent convoy orchestrator (v0.5.0) with beads (v0.49.3)
- `devShells.gastown` - Gastown environment with gt, beads, sqlite, and substrate tools
- `packages.gastown` - Build gastown binary standalone
- `packages.beads` - Build beads (bd) binary standalone
- **OpenClaw orchestrator** (`orchestrators/openclaw/`) - Multi-channel AI gateway environment
- `devShells.openclaw` - OpenClaw environment with Node.js 22, pnpm, native build tools, and substrate
- **Ralph orchestrator** (`orchestrators/ralph/`) - Autonomous Claude Code runner
- `devShells.ralph` - Ralph environment with claude-code and substrate tools
- **Claude agent** (`agents/claude/`) - Claude Code CLI via llm-agents.nix
- `devShells.claude` - Standalone Claude Code environment with substrate tools
- `packages.claude` - Build Claude Code package standalone
- **Codex agent** (`agents/codex/`) - OpenAI Codex CLI via llm-agents.nix
- `devShells.codex` - Standalone Codex CLI environment with substrate tools
- `packages.codex` - Build Codex CLI package standalone
- **Gemini agent** (`agents/gemini/`) - Google Gemini CLI via llm-agents.nix
- `devShells.gemini` - Standalone Gemini CLI environment with substrate tools
- **OpenCode agent** (`agents/opencode/`) - OpenCode CLI via llm-agents.nix
- `devShells.opencode` - Standalone OpenCode CLI environment with substrate tools
- **Tool bundles** (`lib/bundles.nix`) - Baseline (28 tools) and complete (61 tools) bundles
- **mkProjectShell** (`lib/mkProjectShell.nix`) - Compose devShell from agentbox.toml configuration
- **mkProfilePackage** (`lib/mkProfilePackage.nix`) - Build profile packages for `nix profile install`
- **Project template** (`templates/project/`) - `nix flake init -t .#project` scaffolds an agentbox.toml-based environment
- **Containerfile** (`images/Containerfile`) - OCI image builder using nix profile install
- **Profile packages** - `schmux-env`, `gastown-env`, `openclaw-env`, `ralph-env` for image building

### Changed

- schmux environment now composes with substrate layer (inherits all substrate tools)
- Simplified agentbox.toml format - `agents`, `bundles`, `packages` are now root-level arrays
- Image building now uses Containerfile with `just build-image` instead of Nix dockerTools
- Consolidated distros/ to one config per orchestrator (removed variant files)
- mkProjectShell and mkProfilePackage now use shared parseAgentboxConfig.nix

### Removed

- `lib/mkProjectImage.nix` - Replaced by Containerfile-based image building
- `lib/mkSlimImage.nix` - Removed nix-portable slim image experiment
- `images/base.nix` - Removed Nix dockerTools base image
- `scripts/build-image.sh` - Replaced by justfile commands
- `packages.base-image` - Removed in favor of Containerfile approach
- `*-image` flake outputs - Removed `schmux-image`, `gastown-image`, `openclaw-image`, `ralph-image`
- `*-baked-image` flake outputs - Removed baked image variants
- `*-full-image` flake outputs - Removed full Nix image variants
- `distros/*-baked.toml` - Consolidated into base distro files
- `distros/*-full.toml` - Consolidated into base distro files
- `distros/*-slim.toml` - Removed slim variant configs
- `distros/*-minimal.toml` - Removed minimal variant configs

### Fixed
