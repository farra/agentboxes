# mkSlimImage - Build a slim bootstrap OCI image from agentbox.toml
#
# Creates a wolfi-based image with minimal bootstrap tooling. The full environment
# is installed on first boot via `nix profile install`.
#
# Included bootstrap tools:
#   - nix: Core package manager (installs everything else)
#   - git: Required for flake fetching
#   - just: Command runner for bootstrap/update commands
#   - direnv: Auto-activate environments
#   - nix-direnv: Cached nix integration for direnv
#   - cacert: SSL certificates for nix
#
# Generated files in /etc/skel/ (copied to ~ on user creation):
#   - ~/.agentboxes/agentbox.toml: The config file
#   - ~/.agentboxes/flake.nix: Generated flake referencing agentboxes
#   - ~/.agentboxes/.envrc: "use flake"
#   - ~/justfile: Commands for bootstrap/update/shell/status/clean
#
# Usage:
#   mkSlimImage { inherit pkgs system; } ./agentbox.toml
#
# Build with: nix build .#schmux-image
# Load with: docker load < result
# Use with distrobox: distrobox create --image <name>:latest --name dev

{ pkgs, system }:

depsPath:

let
  # Parse agentbox.toml
  config = builtins.fromTOML (builtins.readFile depsPath);

  imageName = config.image.name or "agentbox-slim";
  imageTag = config.image.tag or "latest";
  autoBootstrap = config.image.auto_bootstrap or true;

  # Wolfi-toolbox base image (distrobox-ready, glibc, ~200MB)
  wolfiBaseImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/ublue-os/wolfi-toolbox";
    imageDigest = "sha256:28d85a31e854751401264d88c2a337e4081eb56b217f89804d5b44b05aaa7654";
    sha256 = "sha256-yW6TvaqpSSV1hZi4OOot+hV2W7VYgaOHszv2stm9aZ8=";
    finalImageName = "wolfi-toolbox";
    finalImageTag = "latest";
  };

  # Bootstrap packages - minimal set for first-boot installation
  bootstrapPackages = with pkgs; [
    nix
    just
    direnv
    nix-direnv
    cacert
  ];

  # Build a profile with bootstrap tools
  bootstrapProfile = pkgs.buildEnv {
    name = "bootstrap-profile";
    paths = bootstrapPackages;
    pathsToLink = [ "/bin" "/share" "/etc" ];
  };

  # Generate flake.nix that references github:farra/agentboxes
  generatedFlake = pkgs.writeText "flake.nix" ''
    {
      description = "Agentbox environment (auto-generated)";

      inputs.agentboxes.url = "github:farra/agentboxes";

      outputs = { self, agentboxes }:
        agentboxes.lib.mkProjectOutputs ./agentbox.toml;
    }
  '';

  # Justfile for bootstrap operations
  justfileContent = pkgs.writeText "justfile" ''
    # Agentbox bootstrap commands

    # Install the full environment from agentbox.toml
    bootstrap:
        @echo "Installing agentbox environment..."
        cd ~/.agentboxes && nix profile install .#env --refresh
        @echo "Bootstrap complete! Your tools are now available."

    # Update flake inputs and upgrade installed packages
    update:
        @echo "Updating agentbox environment..."
        cd ~/.agentboxes && nix flake update
        nix profile upgrade '.*agentbox.*'
        @echo "Update complete!"

    # Enter a nix develop shell (alternative to direnv)
    shell:
        cd ~/.agentboxes && nix develop

    # Show installed agentbox packages
    status:
        @echo "Installed agentbox packages:"
        @nix profile list | grep -E 'agentbox|env' || echo "  (none installed)"

    # Remove all agentbox packages
    clean:
        @echo "Removing agentbox packages..."
        nix profile remove '.*agentbox.*' || true
        @echo "Cleaned!"
  '';

  # Direnv hook for bash
  direnvHook = pkgs.writeText "direnv-hook.sh" ''
    # Enable direnv for automatic environment activation
    if command -v direnv &> /dev/null; then
      eval "$(direnv hook bash)"
    fi
  '';

  # Auto-bootstrap script (runs on first shell if enabled)
  autoBootstrapScript = pkgs.writeText "agentbox-bootstrap.sh" ''
    # Auto-bootstrap on first login
    if [ ! -f "$HOME/.agentboxes-bootstrapped" ] && [ -f "$HOME/.agentboxes/flake.nix" ]; then
      echo ""
      echo "┌─────────────────────────────────────────┐"
      echo "│  Agentbox: First boot detected          │"
      echo "│  Running bootstrap installation...      │"
      echo "└─────────────────────────────────────────┘"
      echo ""
      if just bootstrap; then
        touch "$HOME/.agentboxes-bootstrapped"
        echo ""
        echo "Bootstrap complete! Your environment is ready."
        echo "Run 'just status' to see installed packages."
        echo ""
      else
        echo ""
        echo "Bootstrap failed. Run 'just bootstrap' to retry."
        echo ""
      fi
    fi
  '';

  # Nix configuration for single-user mode with flakes
  nixConf = pkgs.writeText "nix.conf" ''
    experimental-features = nix-command flakes
    sandbox = false
    trusted-users = *
  '';

in pkgs.dockerTools.buildLayeredImage {
  name = imageName;
  tag = imageTag;
  fromImage = wolfiBaseImage;
  contents = [ bootstrapProfile ];

  config = {
    Cmd = [ "/usr/bin/bash" ];
    Env = [
      "PATH=/nix/profile/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      "TERM=xterm-256color"
      "LANG=en_US.UTF-8"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/";
    Labels = {
      "org.opencontainers.image.description" = "agentbox slim: ${imageName} (bootstrap-only)";
      "org.opencontainers.image.source" = "https://github.com/farra/agentboxes";
      "org.opencontainers.image.base" = "wolfi-toolbox";
      "org.opencontainers.image.variant" = "slim";
    };
  };

  extraCommands = ''
    # Move bootstrap profile to /nix/profile to avoid shadowing wolfi /lib
    if [ -d bin ]; then
      mkdir -p nix/profile
      mv bin nix/profile/
    fi
    if [ -d share ]; then
      mkdir -p nix/profile
      mv share nix/profile/
    fi
    if [ -d etc ]; then
      # Keep etc contents but move to a temp location
      mkdir -p nix/profile
      mv etc nix/profile/ 2>/dev/null || true
    fi

    # Ensure etc exists for our customizations
    mkdir -p etc

    # Set up /etc/skel for distrobox user creation
    mkdir -p etc/skel/.agentboxes

    # Copy agentbox.toml
    cp ${depsPath} etc/skel/.agentboxes/agentbox.toml

    # Copy generated flake.nix
    cp ${generatedFlake} etc/skel/.agentboxes/flake.nix

    # Create .envrc for direnv
    echo "use flake" > etc/skel/.agentboxes/.envrc

    # Copy justfile to home directory
    cp ${justfileContent} etc/skel/justfile

    # Nix configuration for single-user flakes
    mkdir -p etc/nix
    cp ${nixConf} etc/nix/nix.conf

    # SSL certificates (copy from nix cacert package)
    mkdir -p etc/ssl/certs
    cp ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/

    # Profile.d scripts for shell initialization
    mkdir -p etc/profile.d

    # Direnv hook
    cp ${direnvHook} etc/profile.d/direnv-hook.sh
    chmod +x etc/profile.d/direnv-hook.sh

    # Auto-bootstrap on first shell (if enabled)
    ${if autoBootstrap then ''
    cp ${autoBootstrapScript} etc/profile.d/agentbox-bootstrap.sh
    chmod +x etc/profile.d/agentbox-bootstrap.sh
    '' else ""}

    # Welcome banner
    cat > etc/motd << 'MOTD'

    ┌─────────────────────────────────────────┐
    │   ___                  _   ___          │
    │  / _ | ___ ____ ___  _| |_/ _ )___ __ __│
    │ / __ |/ _ `/ -_) _ \/ _  _/ _ / _ \\ \ /│
    │/_/ |_|\_  /\__/_//_/\____|___/\___/_\_\ │
    │       /___/                             │
    │                                         │
    │  Slim Bootstrap Image                   │
    │  Run 'just bootstrap' to install tools  │
    │  https://github.com/farra/agentboxes    │
    └─────────────────────────────────────────┘

MOTD
  '';
}
