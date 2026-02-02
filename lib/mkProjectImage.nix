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
#
# agentbox.toml format (simplified):
#   [image]
#   name = "my-project"
#   base = "wolfi"   # wolfi (smaller, faster) or nix (fully reproducible)
#   tag = "latest"
#
#   [orchestrator]
#   name = "schmux"
#
#   agents = ["claude-code"]
#
#   bundles = ["baseline", "rust-stable"]
#
#   packages = [
#     "python312",
#     "nodejs_22",
#     "htop",
#     "nur:owner/package",
#   ]

{ pkgs, system, substrate ? [], orchestrators ? {}, llmAgentsPkgs ? {}, nurPkgs ? null }:

depsPath:

let
  # Parse agentbox.toml
  config = builtins.fromTOML (builtins.readFile depsPath);

  # =========================================================================
  # Base Image Selection
  # =========================================================================

  imageBase = config.image.base or "nix";
  useWolfiBase = imageBase == "wolfi";

  # Wolfi-toolbox base image (distrobox-ready, glibc, ~200MB)
  # From ublue-os - the Bazzite/Bluefin folks who know immutable distros
  wolfiBaseImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/ublue-os/wolfi-toolbox";
    imageDigest = "sha256:28d85a31e854751401264d88c2a337e4081eb56b217f89804d5b44b05aaa7654";
    sha256 = "sha256-yW6TvaqpSSV1hZi4OOot+hV2W7VYgaOHszv2stm9aZ8=";
    finalImageName = "wolfi-toolbox";
    finalImageTag = "latest";
  };

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
  # Distrobox Compatibility (only for pure Nix images)
  # =========================================================================

  # Map distrobox bundle names to actual packages
  # Some names need special handling (e.g., xorg.xauth is nested)
  mapDistroboxTool = name:
    if name == "xorg.xauth" then pkgs.xorg.xauth
    else pkgs.${name} or null;

  # Only include distrobox packages for pure Nix base (wolfi already has them)
  distroboxPackages = if useWolfiBase then [] else
    builtins.filter (p: p != null) (
      map mapDistroboxTool bundles.distrobox
    );

  # Stub package manager script - makes distrobox think packages are installed
  stubPackageManager = pkgs.writeShellScriptBin "apt-get" ''
    # Stub package manager for distrobox compatibility
    # All required packages are pre-installed in this Nix-based image
    exit 0
  '';

  # Additional stubs for other package managers distrobox might check
  # Only needed for pure Nix base (wolfi has real apk)
  stubPackageManagers = if useWolfiBase then [] else [
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
  # Image Configuration
  # =========================================================================

  imageName = config.image.name or "agentbox";
  imageTag = config.image.tag or "latest";

  # Essential packages for pure Nix base (wolfi already has these)
  essentialPackages = if useWolfiBase then [] else (with pkgs; [
    bashInteractive
    coreutils
    gnugrep
    gnused
    which
  ]);

  # All packages to include in the image
  # When using wolfi base, we skip substrate basics and distrobox deps
  # since wolfi-toolbox already provides them
  allPackages = builtins.filter (p: p != null) (
    (if useWolfiBase then [] else substrate)
    ++ orchestratorPackages
    ++ agentPackages
    ++ rustPackages
    ++ bundlePackages
    ++ extraPackages
    ++ distroboxPackages
    ++ stubPackageManagers
    ++ essentialPackages
  );

  # For wolfi base: put Nix packages in /nix/profile to avoid shadowing /lib, /bin, etc.
  # This prevents conflicts with wolfi's glibc and system binaries
  nixProfile = pkgs.buildEnv {
    name = "nix-profile";
    paths = allPackages;
    # Only link bin directories - avoid lib which would shadow wolfi's libc
    pathsToLink = [ "/bin" "/share" ];
  };

  # Description for logging
  description = builtins.concatStringsSep " + " (
    (if useWolfiBase then [ "wolfi" ] else [ "nix" ])
    ++ (if orchestratorName != null then [ orchestratorName ] else [])
    ++ (if allAgentNames != [] then [ (builtins.concatStringsSep ", " allAgentNames) ] else [])
    ++ (if includedBundles != [] then [ "[${builtins.concatStringsSep ", " includedBundles}]" ] else [])
  );

in pkgs.dockerTools.buildLayeredImage {
  name = imageName;
  tag = imageTag;

  # Use wolfi-toolbox as base when configured, otherwise build from scratch
  fromImage = if useWolfiBase then wolfiBaseImage else null;

  # For wolfi: use nixProfile to avoid shadowing /lib with Nix's symlinks
  # For pure Nix: use allPackages directly (we control the whole filesystem)
  contents = if useWolfiBase then [ nixProfile ] else allPackages;

  config = {
    # Wolfi uses /usr/bin/bash, pure Nix uses /bin/bash
    Cmd = if useWolfiBase then [ "/usr/bin/bash" ] else [ "/bin/bash" ];
    Env = [
      # For wolfi: add /nix/profile/bin where we put Nix packages
      # For pure Nix: standard paths
      (if useWolfiBase
        then "PATH=/nix/profile/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        else "PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
      "TERM=xterm-256color"
      "LANG=en_US.UTF-8"
    ];
    WorkingDir = "/";
    Labels = {
      "org.opencontainers.image.description" = "agentbox: ${description}";
      "org.opencontainers.image.source" = "https://github.com/farra/agentboxes";
      "org.opencontainers.image.base" = if useWolfiBase then "wolfi-toolbox" else "nix";
    };
  };

  # Create necessary directories and distrobox compatibility files
  # For wolfi base, most of this is already handled - we just add Nix bin symlinks
  extraCommands = if useWolfiBase then ''
    # Wolfi base already has distrobox compatibility set up
    # The nixProfile is placed at / but only contains /bin and /share
    # We need to move it to /nix/profile
    if [ -d bin ]; then
      mkdir -p nix/profile
      mv bin nix/profile/
    fi
    if [ -d share ]; then
      mkdir -p nix/profile
      mv share nix/profile/
    fi

    # Ensure etc exists for our customizations
    mkdir -p etc

    # Add welcome banner
    cat > etc/motd << 'MOTD'

    ┌─────────────────────────────────────────┐
    │   ___                  _   ___          │
    │  / _ | ___ ____ ___  _| |_/ _ )___ __ __│
    │ / __ |/ _ `/ -_) _ \/ _  _/ _ / _ \\ \ /│
    │/_/ |_|\_  /\__/_//_/\____|___/\___/_\_\ │
    │       /___/                             │
    │                                         │
    │  Reproducible AI Agent Environments     │
    │  wolfi-toolbox base + Nix packages      │
    │  https://github.com/farra/agentboxes    │
    └─────────────────────────────────────────┘

MOTD
  '' else ''
    mkdir -p tmp home root etc var/empty usr/bin usr/sbin sbin
    chmod 1777 tmp

    # Remove any existing symlinks from packages (e.g., shadow provides login.defs)
    # These point to read-only Nix store paths, so we need to replace them
    rm -f etc/os-release etc/passwd etc/group etc/shadow etc/gshadow etc/login.defs etc/shells etc/locale.conf 2>/dev/null || true

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
