# Claude Code agent wrapper
#
# Wraps the claude-code package from llm-agents.nix with substrate tools.

{ pkgs, substrate ? [], claude-code }:

let
  package = claude-code;

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
