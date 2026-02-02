# OpenClaw orchestrator
#
# Multi-channel AI gateway. Uses the openclaw package from llm-agents.nix.
# This is just a shell wrapper since the package comes from upstream.

{ pkgs, system, substrate ? [], openclaw-pkg }:

let
  # Shell for running openclaw
  shell = pkgs.mkShell {
    packages = [ openclaw-pkg ] ++ substrate;

    shellHook = ''
      echo "openclaw environment"
      openclaw --version 2>/dev/null || echo "Run 'openclaw' to start"
    '';
  };

in {
  # Package comes from llm-agents.nix
  package = openclaw-pkg;
  inherit shell;
}
