# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Substrate layer** (`lib/substrate.nix`) - Common tools shared across all environments: git, curl, wget, jq, yq-go, ripgrep, fd, fzf, tree, less, file, openssh, rsync, tmux, htop
- **Base OCI image** (`images/base.nix`) - Minimal container image with substrate tools, suitable for distrobox or direct deployment
- `devShells.substrate` - Direct access to substrate tools without an orchestrator
- `packages.base-image` - Build the base OCI image with `nix build .#base-image`

### Changed

- schmux environment now composes with substrate layer (inherits all substrate tools)

### Fixed

### Removed
