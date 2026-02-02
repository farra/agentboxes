# Codex CLI agent wrapper
#
# Wraps the codex package from llm-agents.nix with substrate tools.

{ pkgs, substrate ? [], codex }:

let
  package = codex;

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
