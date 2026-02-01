# Codex CLI agent wrapper
#
# Uses the community-maintained codex-cli-nix flake for the package,
# and wraps it in a shell with substrate tools.

{ pkgs, system, substrate ? [], codex-cli-input }:

let
  # Get the package from the external flake
  package = codex-cli-input.packages.${system}.default;

  # Shell for running Codex CLI
  # Composes: substrate + codex-cli package
  shell = pkgs.mkShell {
    packages = [ package ] ++ substrate;

    shellHook = ''
      echo "Codex CLI environment"
      codex --version 2>/dev/null || echo "Run 'codex' to start"
    '';
  };

in {
  inherit package shell;
}
