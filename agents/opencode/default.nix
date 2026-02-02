# OpenCode agent wrapper
#
# Wraps the opencode package from llm-agents.nix with substrate tools.

{ pkgs, substrate ? [], opencode }:

let
  package = opencode;

  shell = pkgs.mkShell {
    packages = [ package ] ++ substrate;

    shellHook = ''
      echo "OpenCode environment"
      opencode --version 2>/dev/null || echo "Run 'opencode' to start"
    '';
  };

in {
  inherit package shell;
}
