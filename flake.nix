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

            mkProjectImage = import ./lib/mkProjectImage.nix {
              inherit pkgs system substrate orchestrators nurPkgs;
              llmAgentsPkgs = llmPkgs;
            };

            mkSlimImage = import ./lib/mkSlimImage.nix {
              inherit pkgs system;
            };

            mkProfilePackage = import ./lib/mkProfilePackage.nix {
              inherit pkgs system substrate orchestrators nurPkgs;
              llmAgentsPkgs = llmPkgs;
            };

            # Parse config to determine image variant
            config = builtins.fromTOML (builtins.readFile depsPath);
            variant = config.image.variant or "slim";

            # Route to appropriate image builder based on variant
            # slim (default): bootstrap image with on-demand installation
            # baked: all tools pre-installed in image
            mkImage = if variant == "baked"
              then mkProjectImage
              else mkSlimImage;
          in {
            devShells.default = mkProjectShell depsPath;
            packages = {
              default = mkProjectShell depsPath;
              image = mkImage depsPath;
              env = mkProfilePackage depsPath;
            };
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

        # Import NUR for image building
        nurPkgs = import nur { inherit pkgs; nurpkgs = pkgs; };

        # Orchestrator map for image building
        orchestrators = {
          inherit schmux gastown openclaw ralph;
        };

        # mkProjectImage for building baked orchestrator images
        mkProjectImage = import ./lib/mkProjectImage.nix {
          inherit pkgs system substrate orchestrators nurPkgs;
          llmAgentsPkgs = llmPkgs;
        };

        # mkSlimImage for building slim bootstrap images
        mkSlimImage = import ./lib/mkSlimImage.nix {
          inherit pkgs system;
        };

        # mkProfilePackage for buildEnv packages (for nix profile install)
        mkProfilePackage = import ./lib/mkProfilePackage.nix {
          inherit pkgs system substrate orchestrators nurPkgs;
          llmAgentsPkgs = llmPkgs;
        };

        # Router: select image builder based on variant in config
        # slim (default): bootstrap image with on-demand installation
        # baked: all tools pre-installed in image
        mkImage = depsPath:
          let
            config = builtins.fromTOML (builtins.readFile depsPath);
            variant = config.image.variant or "slim";
          in
            if variant == "baked"
            then mkProjectImage depsPath
            else mkSlimImage depsPath;
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

          # Pre-built orchestrator images (from distros/)
          # Slim images (default): bootstrap-only, tools installed on first boot
          schmux-image = mkImage ./distros/schmux.toml;
          gastown-image = mkImage ./distros/gastown.toml;
          openclaw-image = mkImage ./distros/openclaw.toml;
          ralph-image = mkImage ./distros/ralph.toml;

          # Baked images: all tools pre-installed (larger but faster startup)
          schmux-baked-image = mkProjectImage ./distros/schmux-baked.toml;
          gastown-baked-image = mkProjectImage ./distros/gastown-baked.toml;
          openclaw-baked-image = mkProjectImage ./distros/openclaw-baked.toml;
          ralph-baked-image = mkProjectImage ./distros/ralph-baked.toml;

          # Full images (pure Nix base, ~11GB, fully reproducible)
          schmux-full-image = mkProjectImage ./distros/schmux-full.toml;
          gastown-full-image = mkProjectImage ./distros/gastown-full.toml;
          openclaw-full-image = mkProjectImage ./distros/openclaw-full.toml;
          ralph-full-image = mkProjectImage ./distros/ralph-full.toml;

          # Profile packages (for nix profile install .#<name>-env)
          schmux-env = mkProfilePackage ./distros/schmux.toml;
          gastown-env = mkProfilePackage ./distros/gastown.toml;
          openclaw-env = mkProfilePackage ./distros/openclaw.toml;
          ralph-env = mkProfilePackage ./distros/ralph.toml;

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
