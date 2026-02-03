# mkProjectShell - Create a devShell from agentbox.toml
#
# This is the core composition function that reads an agentbox.toml file and
# produces a devShell with the specified orchestrator, agents, runtimes, and tools.
#
# Usage:
#   mkProjectShell {
#     inherit pkgs system substrate orchestrators llmAgentsPkgs nurPkgs;
#   } ./agentbox.toml

{ pkgs, system, substrate ? [], orchestrators ? {}, llmAgentsPkgs ? {}, nurPkgs ? null }:

depsPath:

let
  parsed = import ./parseAgentboxConfig.nix {
    inherit pkgs system substrate orchestrators llmAgentsPkgs nurPkgs;
  } depsPath;

in pkgs.mkShell {
  packages = parsed.allPackages;

  shellHook = ''
    echo "Project environment: ${parsed.description}"
    ${if parsed.getRustToolchain != null then ''echo "Rust: $(rustc --version)"'' else ""}
  '';
}
