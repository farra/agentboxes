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
  # Distrobox Compatibility (always included in images)
  # =========================================================================

  # Map distrobox bundle names to actual packages
  # Some names need special handling (e.g., xorg.xauth is nested)
  mapDistroboxTool = name:
    if name == "xorg.xauth" then pkgs.xorg.xauth
    else pkgs.${name} or null;

  distroboxPackages = builtins.filter (p: p != null) (
    map mapDistroboxTool bundles.distrobox
  );

  # Stub package manager script - makes distrobox think packages are installed
  stubPackageManager = pkgs.writeShellScriptBin "apt-get" ''
    # Stub package manager for distrobox compatibility
    # All required packages are pre-installed in this Nix-based image
    exit 0
  '';

  # Additional stubs for other package managers distrobox might check
  stubPackageManagers = [
    stubPackageManager
    (pkgs.writeShellScriptBin "dpkg" ''
      # Stub for distrobox - packages pre-installed
      case "$1" in
        -s|--status) exit 0 ;;  # Package status check - pretend installed
        *) exit 0 ;;
      esac
    '')
  ];

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
    ++ distroboxPackages
    ++ stubPackageManagers
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
      "PATH=/bin:/sbin:/usr/bin:/usr/sbin"
      "TERM=xterm-256color"
      "LANG=en_US.UTF-8"
    ];
    WorkingDir = "/";
    Labels = {
      "org.opencontainers.image.description" = "agentbox: ${description}";
      "org.opencontainers.image.source" = "https://github.com/farra/agentboxes";
    };
  };

  # Create necessary directories and distrobox compatibility files
  extraCommands = ''
    mkdir -p tmp home root etc var/empty usr/bin usr/sbin sbin
    chmod 1777 tmp

    # /etc/os-release - required by distrobox to identify the container OS
    # Using "debian" as ID tricks distrobox into using apt-get (our stub)
    cat > etc/os-release << 'EOF'
ID=debian
ID_LIKE=debian
NAME="Agentbox"
PRETTY_NAME="Agentbox (Nix-based)"
VERSION_ID="1.0"
HOME_URL="https://github.com/farra/agentboxes"
EOF

    # /etc/passwd - required for user management
    cat > etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:Nobody:/var/empty:/bin/false
EOF

    # /etc/group - required for group management
    cat > etc/group << 'EOF'
root:x:0:
nobody:x:65534:
wheel:x:10:
sudo:x:27:
EOF

    # /etc/shadow - some tools expect this (writable for useradd)
    cat > etc/shadow << 'EOF'
root:!:1::::::
nobody:!:1::::::
EOF
    chmod 640 etc/shadow

    # /etc/gshadow - group shadow file
    cat > etc/gshadow << 'EOF'
root:::
nobody:::
wheel:::
sudo:::
EOF
    chmod 640 etc/gshadow

    # /etc/sudoers.d for distrobox to add user sudo access
    mkdir -p etc/sudoers.d
    chmod 750 etc/sudoers.d

    # Symlinks for tools in standard locations (distrobox expects /usr/bin)
    ln -sf /bin/bash usr/bin/bash 2>/dev/null || true
    ln -sf /bin/env usr/bin/env 2>/dev/null || true
    ln -sf /bin/sh usr/bin/sh 2>/dev/null || true

    # /etc/login.defs - required by shadow tools (useradd, etc.)
    cat > etc/login.defs << 'EOF'
MAIL_DIR        /var/mail
FAILLOG_ENAB    yes
LOG_UNKFAIL_ENAB no
LOG_OK_LOGINS   no
SYSLOG_SU_ENAB  yes
SYSLOG_SG_ENAB  yes
SU_NAME         su
ENV_SUPATH      PATH=/bin:/sbin:/usr/bin:/usr/sbin
ENV_PATH        PATH=/bin:/usr/bin
UID_MIN         1000
UID_MAX         60000
GID_MIN         1000
GID_MAX         60000
USERGROUPS_ENAB yes
ENCRYPT_METHOD  SHA512
EOF

    # /etc/shells - list of valid login shells
    cat > etc/shells << 'EOF'
/bin/sh
/bin/bash
/usr/bin/bash
EOF

    # Empty locale files (distrobox reads these)
    mkdir -p etc/default
    echo 'LANG=en_US.UTF-8' > etc/locale.conf
    echo 'LANG="en_US.UTF-8"' > etc/default/locale

    # Welcome banner (shown on login via /etc/motd)
    cat > etc/motd << 'MOTD'

    ┌─────────────────────────────────────────┐
    │   ___                  _   ___          │
    │  / _ | ___ ____ ___  _| |_/ _ )___ __ __│
    │ / __ |/ _ `/ -_) _ \/ _  _/ _ / _ \\ \ /│
    │/_/ |_|\_  /\__/_//_/\____|___/\___/_\_\ │
    │       /___/                             │
    │                                         │
    │  Reproducible AI Agent Environments     │
    │  https://github.com/farra/agentboxes    │
    └─────────────────────────────────────────┘

MOTD

    # Also show on interactive shell start (for shells that don't read motd)
    mkdir -p etc/profile.d
    cat > etc/profile.d/agentbox-welcome.sh << 'PROFILE'
# Show welcome banner once per session
if [ -z "$AGENTBOX_WELCOMED" ] && [ -f /etc/motd ]; then
    cat /etc/motd
    export AGENTBOX_WELCOMED=1
fi
PROFILE
    chmod +x etc/profile.d/agentbox-welcome.sh
  '';
}
