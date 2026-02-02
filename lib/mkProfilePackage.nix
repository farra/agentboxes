# mkProfilePackage - Create a buildEnv from agentbox.toml
#
# This creates a profile package that can be installed via `nix profile install .#env`.
# Used by slim bootstrap images for on-demand installation of the full environment.
#
# Usage:
#   mkProfilePackage {
#     inherit pkgs system substrate orchestrators llmAgentsPkgs nurPkgs;
#   } ./agentbox.toml
#
# Then: nix profile install .#env

{ pkgs, system, substrate ? [], orchestrators ? {}, llmAgentsPkgs ? {}, nurPkgs ? null }:

depsPath:

let
  # Parse agentbox.toml
  config = builtins.fromTOML (builtins.readFile depsPath);

  # Load bundle definitions
  bundles = import ./bundles.nix;

  # =========================================================================
  # Bundles
  # =========================================================================

  includedBundles = config.bundles or [];

  # Check for rust bundles (handled specially via rust-overlay)
  hasRustStable = builtins.elem "rust-stable" includedBundles;
  hasRustNightly = builtins.elem "rust-nightly" includedBundles;
  hasRustBeta = builtins.elem "rust-beta" includedBundles;

  # Get rust toolchain if a rust bundle is requested
  getRustToolchain =
    let
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

  bundlePackages = builtins.filter (p: p != null) (
    map (name: pkgs.${name} or null) bundleToolNames
  );

  # =========================================================================
  # Orchestrator
  # =========================================================================

  orchestratorName = config.orchestrator.name or null;
  orchestrator = if orchestratorName != null
    then orchestrators.${orchestratorName} or null
    else null;
  orchestratorPackages = if orchestrator != null
    then [ orchestrator.package ]
    else [];

  # =========================================================================
  # LLM Agents
  # =========================================================================

  agentNames = config.agents or [];

  # Auto-include agents for agent-specific orchestrators
  autoIncludedAgents =
    if orchestratorName == "ralph" then [ "claude-code" ]
    else [];

  allAgentNames = pkgs.lib.unique (agentNames ++ autoIncludedAgents);

  agentPackages = builtins.filter (p: p != null) (
    map (name:
      if builtins.hasAttr name llmAgentsPkgs
      then llmAgentsPkgs.${name}
      else builtins.trace "Warning: Unknown llm-agent: ${name}" null
    ) allAgentNames
  );

  # =========================================================================
  # Packages (nixpkgs + NUR with nur: prefix)
  # =========================================================================

  packageSpecs = config.packages or [];

  parsePackageSpec = spec:
    if builtins.substring 0 4 spec == "nur:" then
      let
        nurSpec = builtins.substring 4 (-1) spec;
        parts = builtins.split "/" nurSpec;
        owner = builtins.elemAt parts 0;
        pkg = builtins.elemAt parts 2;
      in
        if nurPkgs == null then null
        else if !(nurPkgs.repos ? ${owner}) then null
        else if !(nurPkgs.repos.${owner} ? ${pkg}) then null
        else nurPkgs.repos.${owner}.${pkg}
    else
      pkgs.${spec} or null;

  extraPackages = builtins.filter (p: p != null) (map parsePackageSpec packageSpecs);

  # =========================================================================
  # Build Environment
  # =========================================================================

  imageName = config.image.name or "default";

  allPackages = builtins.filter (p: p != null) (
    substrate
    ++ orchestratorPackages
    ++ agentPackages
    ++ rustPackages
    ++ bundlePackages
    ++ extraPackages
  );

in pkgs.buildEnv {
  name = "agentbox-env-${imageName}";
  paths = allPackages;
  pathsToLink = [ "/bin" "/share" "/lib" ];
}
