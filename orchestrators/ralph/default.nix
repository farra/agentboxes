# Ralph Wiggum orchestrator environment
#
# Ralph is a bash-based autonomous development loop for Claude Code.
# Unlike schmux/gastown (pre-built binaries), Ralph is a collection of scripts.
# Unlike openclaw (npm installed), Ralph is vendored and wrapped directly.
#
# Usage:
#   nix develop .#ralph
#   ralph-enable    # Enable Ralph in current project
#   ralph --monitor # Start autonomous loop with dashboard

{ pkgs, system, substrate ? [], claude-code-input, ralph-src }:

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

  # Claude Code from flake input (ralph requires it)
  claudeCode = claude-code-input.packages.${system}.default;

  # Ralph source from flake input (not vendor directory)
  ralphSrc = ralph-src;

  # Wrapper scripts that set up PATH and source ralph
  ralph = pkgs.writeShellScriptBin "ralph" ''
    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"
    export PATH="${claudeCode}/bin:$PATH"
    exec ${ralphSrc}/ralph_loop.sh "$@"
  '';

  ralphMonitor = pkgs.writeShellScriptBin "ralph-monitor" ''
    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"
    exec ${ralphSrc}/ralph_monitor.sh "$@"
  '';

  ralphEnable = pkgs.writeShellScriptBin "ralph-enable" ''
    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"
    export PATH="${claudeCode}/bin:$PATH"
    # ralph_enable.sh needs to find its lib/ and templates/ directories
    export RALPH_HOME="${ralphSrc}"
    exec ${ralphSrc}/ralph_enable.sh "$@"
  '';

  # Combined package with all ralph commands
  package = pkgs.symlinkJoin {
    name = "ralph";
    paths = [ ralph ralphMonitor ralphEnable ];
  };

  # Shell for running ralph
  # Composes: substrate + ralph commands + claude code + runtime deps
  shell = pkgs.mkShell {
    packages = [ ralph ralphMonitor ralphEnable claudeCode ] ++ runtimeDeps ++ substrate;

    shellHook = ''
      echo "Ralph Wiggum autonomous Claude runner"
      echo "Commands: ralph, ralph-monitor, ralph-enable"
      echo ""
      echo "Quick start:"
      echo "  ralph-enable    # Enable Ralph in current project"
      echo "  ralph --monitor # Start autonomous loop with dashboard"
    '';
  };

in
{
  inherit package shell;
}
