{
  description = "Reproducible environments for AI coding agents and orchestrators";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import substrate (common tools layer)
        substrate = import ./lib/substrate.nix { inherit pkgs; };

        # Import orchestrator packages
        schmux = import ./orchestrators/schmux { inherit pkgs system substrate; };
        gastown = import ./orchestrators/gastown { inherit pkgs system substrate; };
        openclaw = import ./orchestrators/openclaw { inherit pkgs system substrate; };

        # Import OCI image builders
        baseImage = import ./images/base.nix { inherit pkgs substrate; };
      in
      {
        # Packages that can be built
        packages = {
          schmux = schmux.package;
          gastown = gastown.package;
          beads = gastown.beads;
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

          schmux = schmux.shell;
          gastown = gastown.shell;
          openclaw = openclaw.shell;
          default = schmux.shell;
        };
      }
    );
}
