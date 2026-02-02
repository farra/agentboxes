# Gemini CLI agent wrapper
#
# Wraps the gemini-cli package from llm-agents.nix with substrate tools.

{ pkgs, substrate ? [], gemini-cli }:

let
  package = gemini-cli;

  shell = pkgs.mkShell {
    packages = [ package ] ++ substrate;

    shellHook = ''
      echo "Gemini CLI environment"
      gemini --version 2>/dev/null || echo "Run 'gemini' to start"
    '';
  };

in {
  inherit package shell;
}
