# mkProjectShell - Create a devShell from deps.toml
#
# This is the core composition function that reads a deps.toml file and
# produces a devShell with the specified orchestrator, agents, runtimes, and tools.
#
# Usage:
#   mkProjectShell {
#     inherit pkgs system substrate orchestrators agents;
#   } ./deps.toml
#
# deps.toml format:
#   [orchestrator]
#   name = "schmux"
#
#   [agents]
#   claude = true
#   codex = true
#
#   [runtimes]
#   python = "3.12"
#   nodejs = "20"
#   go = "1.23"
#
#   [bundles]
#   include = ["complete"]

{ pkgs, system, substrate ? [], orchestrators ? {}, agents ? {} }:

depsPath:

let
  # Parse deps.toml
  deps = builtins.fromTOML (builtins.readFile depsPath);

  # Load bundle definitions
  bundles = import ./bundles.nix;

  # Version mappings for runtimes with non-standard naming
  versionMap = {
    python = {
      "3.10" = pkgs.python310;
      "3.11" = pkgs.python311;
      "3.12" = pkgs.python312;
      "3.13" = pkgs.python313;
    };
    nodejs = {
      "18" = pkgs.nodejs_18;
      "20" = pkgs.nodejs_20;
      "22" = pkgs.nodejs_22;
    };
    go = {
      "1.21" = pkgs.go_1_21;
      "1.22" = pkgs.go_1_22;
      "1.23" = pkgs.go_1_23;
      "1.24" = pkgs.go_1_24 or pkgs.go;
    };
  };

  # Map a runtime name + version to a package
  mapRuntime = name: version:
    let
      fromVersionMap = versionMap.${name}.${version} or null;
      fromPkgs = pkgs.${name} or null;
    in
      if fromVersionMap != null then fromVersionMap
      else if fromPkgs != null then fromPkgs
      else builtins.trace "Warning: Unknown runtime ${name} ${version}" null;

  # Resolve runtimes from deps.toml
  runtimePackages = builtins.filter (p: p != null) (
    builtins.attrValues (
      builtins.mapAttrs mapRuntime (deps.runtimes or {})
    )
  );

  # Resolve bundles from deps.toml
  includedBundles = deps.bundles.include or [ "complete" ];
  bundleToolNames = builtins.concatLists (
    map (name: bundles.${name} or []) includedBundles
  );

  # Resolve bundle tool names to packages (filter nulls for missing packages)
  bundlePackages = builtins.filter (p: p != null) (
    map (name: pkgs.${name} or null) bundleToolNames
  );

  # Resolve orchestrator
  orchestratorName = deps.orchestrator.name or null;
  orchestrator = if orchestratorName != null
    then orchestrators.${orchestratorName} or null
    else null;
  orchestratorPackages = if orchestrator != null
    then [ orchestrator.package ]
    else [];

  # Resolve agents
  agentNames = builtins.attrNames (deps.agents or {});
  enabledAgents = builtins.filter (name: deps.agents.${name} == true) agentNames;
  agentPackages = builtins.filter (p: p != null) (
    map (name: (agents.${name} or {}).package or null) enabledAgents
  );

  # Build description for shellHook
  description = builtins.concatStringsSep " + " (
    (if orchestratorName != null then [ orchestratorName ] else [])
    ++ (if enabledAgents != [] then [ (builtins.concatStringsSep ", " enabledAgents) ] else [])
    ++ (if includedBundles != [] then [ "[${builtins.concatStringsSep ", " includedBundles}]" ] else [])
  );

in pkgs.mkShell {
  packages = builtins.filter (p: p != null) (
    substrate
    ++ orchestratorPackages
    ++ agentPackages
    ++ runtimePackages
    ++ bundlePackages
  );

  shellHook = ''
    echo "Project environment: ${description}"
  '';
}
