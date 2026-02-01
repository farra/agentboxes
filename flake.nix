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

        # Import orchestrator packages
        schmux = import ./orchestrators/schmux { inherit pkgs system; };
      in
      {
        # Packages that can be built
        packages = {
          schmux = schmux.package;
          default = schmux.package;
        };

        # Development/runtime shells
        devShells = {
          schmux = schmux.shell;
          default = schmux.shell;
        };
      }
    );
}
