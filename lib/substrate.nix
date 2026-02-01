# Substrate layer: Common tools available in all agentboxes environments
#
# This provides the foundation that all orchestrators and agents build upon.
# Tools here are essential for development workflows, debugging, and operations.

{ pkgs }:

with pkgs; [
  # Core utilities
  git
  curl
  wget
  bash
  coreutils
  gnugrep
  gnused
  which

  # Data processing
  jq
  yq-go

  # Search and navigation
  ripgrep
  fd
  fzf

  # Inspection
  tree
  less
  file

  # Network
  openssh
  rsync

  # Process management
  tmux
  htop
]
