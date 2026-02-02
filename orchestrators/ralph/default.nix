# Ralph Wiggum orchestrator
#
# Bash-based autonomous development loop for Claude Code.
# Unlike schmux/gastown (pre-built binaries), Ralph is a collection of scripts.
#
# Ralph is not yet in llm-agents.nix. This package is structured to be
# submittable in the future.
#
# Usage:
#   nix develop .#ralph
#   ralph-enable    # Enable Ralph in current project
#   ralph --monitor # Start autonomous loop with dashboard

{ pkgs, system, substrate ? [], ralph-src, claude-code }:

let
  # Ralph's runtime dependencies
  runtimeDeps = with pkgs; [
    bash
    jq
    git
    tmux
    coreutils
    gnugrep
    gnused
    gawk
  ];

  # Wrapper scripts that set up PATH and execute ralph
  ralph = pkgs.writeShellScriptBin "ralph" ''
    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"
    export PATH="${claude-code}/bin:$PATH"
    exec ${ralph-src}/ralph_loop.sh "$@"
  '';

  ralphMonitor = pkgs.writeShellScriptBin "ralph-monitor" ''
    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"
    exec ${ralph-src}/ralph_monitor.sh "$@"
  '';

  ralphEnable = pkgs.writeShellScriptBin "ralph-enable" ''
    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"
    export PATH="${claude-code}/bin:$PATH"
    # ralph_enable.sh needs to find its lib/ and templates/ directories
    export RALPH_HOME="${ralph-src}"
    exec ${ralph-src}/ralph_enable.sh "$@"
  '';

  # Combined package with all ralph commands
  package = pkgs.symlinkJoin {
    name = "ralph";
    paths = [ ralph ralphMonitor ralphEnable ];

    # For future llm-agents.nix submission
    passthru.category = "Workflow & Project Management";

    meta = with pkgs.lib; {
      description = "Ralph Wiggum - Autonomous development loop for Claude Code";
      homepage = "https://github.com/frankbria/ralph-claude-code";
      license = licenses.asl20;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.unix;
      mainProgram = "ralph";
    };
  };

  # Shell for running ralph
  shell = pkgs.mkShell {
    packages = [ ralph ralphMonitor ralphEnable claude-code ] ++ runtimeDeps ++ substrate;

    shellHook = ''
      echo "Ralph Wiggum autonomous Claude runner"
      echo "Commands: ralph, ralph-monitor, ralph-enable"
      echo ""
      echo "Quick start:"
      echo "  ralph-enable    # Enable Ralph in current project"
      echo "  ralph --monitor # Start autonomous loop with dashboard"
    '';
  };

in {
  inherit package shell;
}
