# Claude Code agent wrapper
#
# Uses the community-maintained claude-code-nix flake for the package,
# and wraps it in a shell with substrate tools.

{ pkgs, system, substrate ? [], claude-code-input }:

let
  # Get the package from the external flake
  package = claude-code-input.packages.${system}.default;

  # Shell for running Claude Code
  # Composes: substrate + claude-code package
  shell = pkgs.mkShell {
    packages = [ package ] ++ substrate;

    shellHook = ''
      echo "Claude Code environment"
      claude --version 2>/dev/null || echo "Run 'claude' to start"
    '';
  };

in {
  inherit package shell;
}
