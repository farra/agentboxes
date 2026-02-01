{
  description = "Reproducible environments for AI coding agents and orchestrators";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Agent flakes (community-maintained, fast-updating)
    claude-code.url = "github:sadjow/claude-code-nix";
    codex-cli.url = "github:sadjow/codex-cli-nix";
  };

  outputs = { self, nixpkgs, flake-utils, claude-code, codex-cli }:
    let
      # System-independent outputs
      templates = {
        project = {
          path = ./templates/project;
          description = "Project environment with orchestrator, agents, and tools from deps.toml";
        };
      };

      # Helper to create project outputs from deps.toml
      # Usage in downstream flakes:
      #   outputs = { agentboxes, ... }: agentboxes.lib.mkProjectOutputs ./deps.toml;
      mkProjectOutputs = depsPath:
        flake-utils.lib.eachDefaultSystem (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            substrate = import ./lib/substrate.nix { inherit pkgs; };

            # Import orchestrators
            orchestrators = {
              schmux = import ./orchestrators/schmux { inherit pkgs system substrate; };
              gastown = import ./orchestrators/gastown { inherit pkgs system substrate; };
              openclaw = import ./orchestrators/openclaw { inherit pkgs system substrate; };
            };

            # Import agents
            agents = {
              claude = import ./agents/claude {
                inherit pkgs system substrate;
                claude-code-input = claude-code;
              };
              codex = import ./agents/codex {
                inherit pkgs system substrate;
                codex-cli-input = codex-cli;
              };
            };

            mkProjectShell = import ./lib/mkProjectShell.nix {
              inherit pkgs system substrate orchestrators agents;
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

        # Import orchestrator packages
        schmux = import ./orchestrators/schmux { inherit pkgs system substrate; };
        gastown = import ./orchestrators/gastown { inherit pkgs system substrate; };
        openclaw = import ./orchestrators/openclaw { inherit pkgs system substrate; };

        # Import agent packages
        claude = import ./agents/claude {
          inherit pkgs system substrate;
          claude-code-input = claude-code;
        };
        codex = import ./agents/codex {
          inherit pkgs system substrate;
          codex-cli-input = codex-cli;
        };

        # Import OCI image builders
        baseImage = import ./images/base.nix { inherit pkgs substrate; };
      in
      {
        # Packages that can be built
        packages = {
          schmux = schmux.package;
          gastown = gastown.package;
          beads = gastown.beads;
          claude = claude.package;
          codex = codex.package;
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

          # Agents (standalone)
          claude = claude.shell;
          codex = codex.shell;

          default = schmux.shell;
        };
      }
    );
}
