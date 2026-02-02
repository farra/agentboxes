# mkProjectImage - Build an OCI image from agentbox.toml
#
# This is the parallel to mkProjectShell.nix, but outputs an OCI image instead
# of a devShell. The image contains all tools/orchestrators/agents baked in,
# so no `nix develop` is needed at runtime.
#
# Usage:
#   mkProjectImage {
#     inherit pkgs system substrate orchestrators llmAgentsPkgs nurPkgs;
#   } ./agentbox.toml
#
# Build with: nix build .#image
# Load with: docker load < result
# Use with distrobox: distrobox create --image <name>:latest --name dev

{ pkgs, system, substrate ? [], orchestrators ? {}, llmAgentsPkgs ? {}, nurPkgs ? null }:

depsPath:

let
  # Parse agentbox.toml
  config = builtins.fromTOML (builtins.readFile depsPath);

  # Load bundle definitions
  bundles = import ./bundles.nix;

  # =========================================================================
  # Tool Resolution (same as mkProjectShell.nix)
  # =========================================================================

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

  mapTool = name: version:
    let
      fromVersionMap = versionMap.${name}.${version} or null;
      fromPkgs = pkgs.${name} or null;
    in
      if name == "rust" then null
      else if fromVersionMap != null then fromVersionMap
      else if fromPkgs != null then fromPkgs
      else builtins.trace "Warning: Unknown tool ${name} ${version}" null;

  toolsSection = config.tools or config.runtimes or {};

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
      if version == "stable" then pkgs.rust-bin.stable.latest.default or null
      else if version == "beta" then pkgs.rust-bin.beta.latest.default or null
      else if version == "nightly" then pkgs.rust-bin.nightly.latest.default or null
      else if version != null then
        pkgs.rust-bin.stable.${version}.default or null
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

  llmAgentNames = config.llm-agents.include or [];

  legacyNameMap = {
    claude = "claude-code";
    codex = "codex";
    gemini = "gemini-cli";
    opencode = "opencode";
  };
  legacyAgentNames = map (n: legacyNameMap.${n} or n)
    (builtins.filter (n: config.agents.${n} == true) (builtins.attrNames (config.agents or {})));

  autoIncludedAgents =
    if orchestratorName == "ralph" then [ "claude-code" ]
    else [];

  allAgentNames = pkgs.lib.unique (llmAgentNames ++ legacyAgentNames ++ autoIncludedAgents);

  agentPackages = builtins.filter (p: p != null) (
    map (name:
      if builtins.hasAttr name llmAgentsPkgs
      then llmAgentsPkgs.${name}
      else builtins.trace "Warning: Unknown llm-agent: ${name}" null
    ) allAgentNames
  );

  # =========================================================================
  # NUR Packages
  # =========================================================================

  getNurPackages = let
    specs = config.nur.include or [];
    parseSpec = spec: let
      parts = builtins.split "/" spec;
      owner = builtins.elemAt parts 0;
      pkg = builtins.elemAt parts 2;
      repo = nurPkgs.repos.${owner} or null;
    in
      if nurPkgs == null then null
      else if repo == null then null
      else if !(builtins.hasAttr pkg repo) then null
      else repo.${pkg};
  in builtins.filter (p: p != null) (map parseSpec specs);

  nurPackages = getNurPackages;

  # =========================================================================
  # Image Configuration
  # =========================================================================

  imageName = config.image.name or "agentbox";
  imageTag = config.image.tag or "latest";

  # All packages to include in the image
  allPackages = builtins.filter (p: p != null) (
    substrate
    ++ orchestratorPackages
    ++ agentPackages
    ++ toolPackages
    ++ rustPackages
    ++ bundlePackages
    ++ nurPackages
    ++ (with pkgs; [
      # Essential for container operation
      bashInteractive
      coreutils
      gnugrep
      gnused
      which
    ])
  );

  # Description for logging
  description = builtins.concatStringsSep " + " (
    (if orchestratorName != null then [ orchestratorName ] else [])
    ++ (if allAgentNames != [] then [ (builtins.concatStringsSep ", " allAgentNames) ] else [])
    ++ (if includedBundles != [] then [ "[${builtins.concatStringsSep ", " includedBundles}]" ] else [])
  );

in pkgs.dockerTools.buildLayeredImage {
  name = imageName;
  tag = imageTag;

  contents = allPackages;

  config = {
    Cmd = [ "/bin/bash" ];
    Env = [
      "PATH=/bin"
      "TERM=xterm-256color"
    ];
    WorkingDir = "/";
    Labels = {
      "org.opencontainers.image.description" = "agentbox: ${description}";
    };
  };

  # Create necessary directories
  extraCommands = ''
    mkdir -p tmp home root
    chmod 1777 tmp
  '';
}
