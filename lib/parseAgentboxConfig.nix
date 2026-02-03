# parseAgentboxConfig - Shared TOML parsing logic for agentbox.toml
#
# This module extracts and resolves all packages from an agentbox.toml file.
# Used by both mkProjectShell.nix (devShells) and mkProfilePackage.nix (buildEnv).
#
# Usage:
#   parsed = import ./parseAgentboxConfig.nix {
#     inherit pkgs system substrate orchestrators llmAgentsPkgs nurPkgs;
#   } ./agentbox.toml;
#
# Returns:
#   {
#     config         - Raw parsed TOML
#     allPackages    - Combined list of all resolved packages
#     description    - Human-readable description string
#     orchestratorPackages, agentPackages, bundlePackages, rustPackages, extraPackages
#   }

{ pkgs, system, substrate ? [], orchestrators ? {}, llmAgentsPkgs ? {}, nurPkgs ? null }:

depsPath:

let
  # Parse agentbox.toml
  config = builtins.fromTOML (builtins.readFile depsPath);

  # Load bundle definitions
  bundles = import ./bundles.nix;

  # ===========================================================================
  # Bundles
  # ===========================================================================

  includedBundles = config.bundles or [];

  # Check for rust bundles (handled specially via rust-overlay)
  hasRustStable = builtins.elem "rust-stable" includedBundles;
  hasRustNightly = builtins.elem "rust-nightly" includedBundles;
  hasRustBeta = builtins.elem "rust-beta" includedBundles;

  # Get rust toolchain if a rust bundle is requested
  getRustToolchain =
    let
      # rust-overlay may not be available (e.g., in profile packages without overlay)
      toolchain =
        if hasRustStable then pkgs.rust-bin.stable.latest.default or null
        else if hasRustNightly then pkgs.rust-bin.nightly.latest.default or null
        else if hasRustBeta then pkgs.rust-bin.beta.latest.default or null
        else null;
    in
      if toolchain != null then
        toolchain.override { extensions = [ "rustfmt" "clippy" ]; }
      else null;

  rustPackages = if getRustToolchain != null then [ getRustToolchain ] else [];

  # Filter out rust bundles from regular bundle processing
  regularBundles = builtins.filter (b: !(builtins.elem b ["rust-stable" "rust-nightly" "rust-beta"])) includedBundles;

  bundleToolNames = builtins.concatLists (
    map (name: bundles.${name} or []) regularBundles
  );

  # Resolve bundle tool names to packages (filter nulls for missing packages)
  bundlePackages = builtins.filter (p: p != null) (
    map (name: pkgs.${name} or null) bundleToolNames
  );

  # ===========================================================================
  # Orchestrator (agentboxes-specific)
  # ===========================================================================

  orchestratorName = config.orchestrator.name or null;
  orchestrator = if orchestratorName != null
    then orchestrators.${orchestratorName} or null
    else null;
  orchestratorPackages = if orchestrator != null
    then [ orchestrator.package ]
    else [];

  # ===========================================================================
  # LLM Agents
  # ===========================================================================

  agentNames = config.agents or [];

  # Auto-include agents for agent-specific orchestrators
  # Ralph always requires claude-code
  autoIncludedAgents =
    if orchestratorName == "ralph" then [ "claude-code" ]
    else [];

  # Combine all agent names (unique)
  allAgentNames = pkgs.lib.unique (agentNames ++ autoIncludedAgents);

  # Resolve agent names to packages from llm-agents.nix
  agentPackages = builtins.filter (p: p != null) (
    map (name:
      if builtins.hasAttr name llmAgentsPkgs
      then llmAgentsPkgs.${name}
      else builtins.trace "Warning: Unknown llm-agent: ${name}. See github:numtide/llm-agents.nix" null
    ) allAgentNames
  );

  # ===========================================================================
  # Packages (nixpkgs + NUR with nur: prefix)
  # ===========================================================================

  packageSpecs = config.packages or [];

  parsePackageSpec = spec:
    if builtins.substring 0 4 spec == "nur:" then
      let
        nurSpec = builtins.substring 4 (-1) spec;
        parts = builtins.split "/" nurSpec;
        owner = builtins.elemAt parts 0;
        pkg = builtins.elemAt parts 2;
      in
        if nurPkgs == null then
          builtins.trace "Warning: NUR not available, skipping ${spec}" null
        else if !(nurPkgs.repos ? ${owner}) then
          builtins.trace "Warning: Unknown NUR repo: ${owner}" null
        else if !(nurPkgs.repos.${owner} ? ${pkg}) then
          builtins.trace "Warning: Unknown NUR package: ${spec}" null
        else
          nurPkgs.repos.${owner}.${pkg}
    else
      if builtins.hasAttr spec pkgs
      then pkgs.${spec}
      else builtins.trace "Warning: Unknown package: ${spec}" null;

  extraPackages = builtins.filter (p: p != null) (map parsePackageSpec packageSpecs);

  # ===========================================================================
  # Combined Results
  # ===========================================================================

  allPackages = builtins.filter (p: p != null) (
    substrate
    ++ orchestratorPackages
    ++ agentPackages
    ++ rustPackages
    ++ bundlePackages
    ++ extraPackages
  );

  description = builtins.concatStringsSep " + " (
    (if orchestratorName != null then [ orchestratorName ] else [])
    ++ (if allAgentNames != [] then [ (builtins.concatStringsSep ", " allAgentNames) ] else [])
    ++ (if includedBundles != [] then [ "[${builtins.concatStringsSep ", " includedBundles}]" ] else [])
  );

in {
  inherit config allPackages description;
  inherit orchestratorPackages agentPackages bundlePackages rustPackages extraPackages;
  inherit getRustToolchain allAgentNames;
  imageName = config.image.name or "default";
}
