# mkProjectShell - Create a devShell from agentbox.toml
#
# This is the core composition function that reads an agentbox.toml file and
# produces a devShell with the specified orchestrator, agents, runtimes, and tools.
#
# Usage:
#   mkProjectShell {
#     inherit pkgs system substrate orchestrators llmAgentsPkgs nurPkgs;
#   } ./agentbox.toml
#
# agentbox.toml format:
#   [orchestrator]      # agentboxes-specific
#   name = "schmux"
#
#   [bundles]
#   include = ["complete"]
#
#   [tools]
#   python = "3.12"
#   nodejs = "20"
#   rust = "stable"
#
#   [rust]
#   components = ["rustfmt", "clippy"]
#
#   [llm-agents]
#   include = ["claude-code"]
#
#   [nur]
#   include = ["owner/package"]

{ pkgs, system, substrate ? [], orchestrators ? {}, llmAgentsPkgs ? {}, nurPkgs ? null }:

depsPath:

let
  # Parse agentbox.toml
  config = builtins.fromTOML (builtins.readFile depsPath);

  # Load bundle definitions
  bundles = import ./bundles.nix;

  # =========================================================================
  # Tool Resolution (aligned with cautomaton-develops)
  # =========================================================================

  # Version mappings for tools with non-standard naming
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

  # Map a tool name + version to a package
  # Skip rust here - handled separately via getRustToolchain
  mapTool = name: version:
    let
      fromVersionMap = versionMap.${name}.${version} or null;
      fromPkgs = pkgs.${name} or null;
    in
      if name == "rust" then null
      else if fromVersionMap != null then fromVersionMap
      else if fromPkgs != null then fromPkgs
      else builtins.trace "Warning: Unknown tool ${name} ${version}" null;

  # Support both old [runtimes] and new [tools] section names
  toolsSection = config.tools or config.runtimes or {};

  # Resolve tools from agentbox.toml (excluding rust)
  toolPackages = builtins.filter (p: p != null) (
    builtins.attrValues (
      builtins.mapAttrs mapTool toolsSection
    )
  );

  # =========================================================================
  # Rust Toolchain (via rust-overlay)
  # =========================================================================

  getRustToolchain = let
    version = toolsSection.rust or null;
    components = config.rust.components or [ "rustfmt" "clippy" ];

    toolchain =
      if version == "stable" then pkgs.rust-bin.stable.latest.default
      else if version == "beta" then pkgs.rust-bin.beta.latest.default
      else if version == "nightly" then pkgs.rust-bin.nightly.latest.default
      else if version != null then
        # Specific version like "1.75.0"
        pkgs.rust-bin.stable.${version}.default
      else null;
  in
    if toolchain != null then
      toolchain.override { extensions = components; }
    else null;

  rustPackages = if getRustToolchain != null then [ getRustToolchain ] else [];

  # =========================================================================
  # Bundles
  # =========================================================================

  includedBundles = config.bundles.include or [ "complete" ];
  bundleToolNames = builtins.concatLists (
    map (name: bundles.${name} or []) includedBundles
  );

  # Resolve bundle tool names to packages (filter nulls for missing packages)
  bundlePackages = builtins.filter (p: p != null) (
    map (name: pkgs.${name} or null) bundleToolNames
  );

  # =========================================================================
  # Orchestrator (agentboxes-specific)
  # =========================================================================

  orchestratorName = config.orchestrator.name or null;
  orchestrator = if orchestratorName != null
    then orchestrators.${orchestratorName} or null
    else null;
  orchestratorPackages = if orchestrator != null
    then [ orchestrator.package ]
    else [];

  # =========================================================================
  # LLM Agents (aligned with cautomaton-develops)
  # =========================================================================

  # New format: [llm-agents] include = ["claude-code"]
  llmAgentNames = config.llm-agents.include or [];

  # Backwards compat: [agents] claude = true -> claude-code
  legacyNameMap = {
    claude = "claude-code";
    codex = "codex";
    gemini = "gemini-cli";
    opencode = "opencode";
  };
  legacyAgentNames = map (n: legacyNameMap.${n} or n)
    (builtins.filter (n: config.agents.${n} == true) (builtins.attrNames (config.agents or {})));

  # Auto-include agents for agent-specific orchestrators
  # Ralph always requires claude-code
  autoIncludedAgents =
    if orchestratorName == "ralph" then [ "claude-code" ]
    else [];

  # Combine all agent names (unique)
  allAgentNames = pkgs.lib.unique (llmAgentNames ++ legacyAgentNames ++ autoIncludedAgents);

  # Resolve agent names to packages from llm-agents.nix
  agentPackages = builtins.filter (p: p != null) (
    map (name:
      if builtins.hasAttr name llmAgentsPkgs
      then llmAgentsPkgs.${name}
      else builtins.trace "Warning: Unknown llm-agent: ${name}. See github:numtide/llm-agents.nix" null
    ) allAgentNames
  );

  # =========================================================================
  # NUR Packages (aligned with cautomaton-develops)
  # =========================================================================

  getNurPackages = let
    specs = config.nur.include or [];
    parseSpec = spec: let
      parts = builtins.split "/" spec;
      owner = builtins.elemAt parts 0;
      pkg = builtins.elemAt parts 2;
      repo = nurPkgs.repos.${owner} or null;
    in
      if nurPkgs == null then
        builtins.trace "Warning: NUR not available, skipping ${spec}" null
      else if repo == null then
        builtins.trace "Warning: Unknown NUR repo: ${owner}" null
      else if !(builtins.hasAttr pkg repo) then
        builtins.trace "Warning: Unknown NUR package: ${spec}" null
      else
        repo.${pkg};
  in builtins.filter (p: p != null) (map parseSpec specs);

  nurPackages = getNurPackages;

  # =========================================================================
  # Build Description
  # =========================================================================

  description = builtins.concatStringsSep " + " (
    (if orchestratorName != null then [ orchestratorName ] else [])
    ++ (if allAgentNames != [] then [ (builtins.concatStringsSep ", " allAgentNames) ] else [])
    ++ (if includedBundles != [] then [ "[${builtins.concatStringsSep ", " includedBundles}]" ] else [])
  );

in pkgs.mkShell {
  packages = builtins.filter (p: p != null) (
    substrate
    ++ orchestratorPackages
    ++ agentPackages
    ++ toolPackages
    ++ rustPackages
    ++ bundlePackages
    ++ nurPackages
  );

  shellHook = ''
    echo "Project environment: ${description}"
    ${if getRustToolchain != null then ''echo "Rust: $(rustc --version)"'' else ""}
  '';
}
