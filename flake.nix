{
  description = "Reproducible environments for AI coding agents and orchestrators";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Single source for all AI coding agents (daily updates, binary cache)
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";

    # Rust toolchain support
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Nix User Repository (community packages)
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    # Orchestrator sources (not yet in llm-agents.nix)
    ralph-src = {
      url = "github:frankbria/ralph-claude-code";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, llm-agents, rust-overlay, nur, ralph-src }:
    let
      # System-independent outputs
      templates = {
        project = {
          path = ./templates/project;
          description = "Project environment with orchestrator, agents, and tools from agentbox.toml";
        };
      };

      # Helper to create project outputs from agentbox.toml
      # Usage in downstream flakes:
      #   outputs = { agentboxes, ... }: agentboxes.lib.mkProjectOutputs ./agentbox.toml;
      mkProjectOutputs = depsPath:
        flake-utils.lib.eachDefaultSystem (system:
          let
            # Apply rust-overlay for rust toolchain support
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ rust-overlay.overlays.default ];
            };
            substrate = import ./lib/substrate.nix { inherit pkgs; };
            llmPkgs = llm-agents.packages.${system};

            # Import NUR
            nurPkgs = import nur { inherit pkgs; nurpkgs = pkgs; };

            # Import orchestrators
            orchestrators = {
              schmux = import ./orchestrators/schmux { inherit pkgs system substrate; };
              gastown = import ./orchestrators/gastown {
                inherit pkgs system substrate;
                beads = llmPkgs.beads;
              };
              openclaw = import ./orchestrators/openclaw {
                inherit pkgs system substrate;
                openclaw-pkg = llmPkgs.openclaw;
              };
              ralph = import ./orchestrators/ralph {
                inherit pkgs system substrate ralph-src;
                claude-code = llmPkgs.claude-code;
              };
            };

            mkProjectShell = import ./lib/mkProjectShell.nix {
              inherit pkgs system substrate orchestrators nurPkgs;
              llmAgentsPkgs = llmPkgs;
            };
          in {
            devShells.default = mkProjectShell depsPath;
          }
        );

      lib = {
        inherit mkProjectOutputs;
      };

    in
    # Merge system-independent outputs with per-system outputs
    {
      inherit templates lib;
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import substrate (common tools layer)
        substrate = import ./lib/substrate.nix { inherit pkgs; };

        # Get packages from llm-agents.nix
        llmPkgs = llm-agents.packages.${system};

        # Import orchestrator packages
        schmux = import ./orchestrators/schmux { inherit pkgs system substrate; };
        gastown = import ./orchestrators/gastown {
          inherit pkgs system substrate;
          beads = llmPkgs.beads;
        };
        openclaw = import ./orchestrators/openclaw {
          inherit pkgs system substrate;
          openclaw-pkg = llmPkgs.openclaw;
        };
        ralph = import ./orchestrators/ralph {
          inherit pkgs system substrate ralph-src;
          claude-code = llmPkgs.claude-code;
        };

        # Import agent wrappers
        claude = import ./agents/claude {
          inherit pkgs substrate;
          claude-code = llmPkgs.claude-code;
        };
        codex = import ./agents/codex {
          inherit pkgs substrate;
          codex = llmPkgs.codex;
        };
        gemini = import ./agents/gemini {
          inherit pkgs substrate;
          gemini-cli = llmPkgs.gemini-cli;
        };
        opencode = import ./agents/opencode {
          inherit pkgs substrate;
          opencode = llmPkgs.opencode;
        };

        # Import OCI image builders
        baseImage = import ./images/base.nix { inherit pkgs substrate; };
      in
      {
        # Packages that can be built
        packages = {
          # Orchestrators
          schmux = schmux.package;
          gastown = gastown.package;
          ralph = ralph.package;
          # Note: openclaw package comes from llm-agents.nix

          # Agents (re-exported from llm-agents.nix)
          claude = claude.package;
          codex = codex.package;
          gemini = gemini.package;
          opencode = opencode.package;

          # Utilities
          beads = llmPkgs.beads;
          base-image = baseImage;

          default = schmux.package;
        };

        # Development/runtime shells
        devShells = {
          # Substrate: just the common tools layer
          substrate = pkgs.mkShell {
            packages = substrate;
            shellHook = ''
              echo "agentboxes substrate environment"
              echo "Common tools: git, jq, rg, fd, fzf, tmux, htop, etc."
            '';
          };

          # Orchestrators
          schmux = schmux.shell;
          gastown = gastown.shell;
          openclaw = openclaw.shell;
          ralph = ralph.shell;

          # Agents (standalone)
          claude = claude.shell;
          codex = codex.shell;
          gemini = gemini.shell;
          opencode = opencode.shell;

          default = schmux.shell;
        };
      }
    );
}
