# mkSlimImage - Build a slim bootstrap OCI image from agentbox.toml
#
# Creates a wolfi-based image with minimal bootstrap tooling. The full environment
# is installed on first boot via `nix profile install`.
#
# Included bootstrap tools:
#   - nix-portable: Rootless nix that works anywhere (no /nix required)
#   - just: Command runner for bootstrap/update commands
#   - direnv: Auto-activate environments
#   - nix-direnv: Cached nix integration for direnv
#   - cacert: SSL certificates for nix
#
# Generated files in /etc/skel/ (copied to ~ on first shell):
#   - ~/.agentboxes/agentbox.toml: The config file
#   - ~/.agentboxes/flake.nix: Generated flake referencing agentboxes
#   - ~/.agentboxes/.envrc: "use flake"
#   - ~/justfile: Commands for bootstrap/update/shell/status/clean
#
# Note: distrobox mounts the host home directory, so /etc/skel isn't copied
# automatically. The bootstrap script handles copying these files on first run.
#
# nix-portable stores its data in ~/.nix-portable, which persists across
# container restarts when using distrobox (since it mounts host home).
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

  # Fetch nix-portable - works without root and without /nix
  # https://github.com/DavHau/nix-portable
  nixPortable = pkgs.fetchurl {
    url = "https://github.com/DavHau/nix-portable/releases/download/v012/nix-portable-x86_64";
    sha256 = "sha256-1/CL4dxQKzIjzTt3/G0j3hEtXbrZ/aPGiChgUxEQU2U=";
    executable = true;
  };

  # Bootstrap packages - minimal set for first-boot installation
  # Note: nix is provided by nix-portable, not nixpkgs
  bootstrapPackages = with pkgs; [
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

  # Wrapper script that makes `nix` call `nix-portable nix`
  nixWrapper = pkgs.writeShellScriptBin "nix" ''
    exec /nix/profile/bin/nix-portable nix "$@"
  '';

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
  # Lives in ~/.agentboxes/justfile - run with: just -f ~/.agentboxes/justfile <cmd>
  # Note: nix-portable stores things in ~/.nix-portable/nix/store/ but profile
  # symlinks point to /nix/store/ (which only exists inside nix-portable's sandbox).
  # We create ~/.agentbox-bin as a stable symlink to the actual store path.
  justfileContent = pkgs.writeText "justfile" ''
    # Agentbox environment commands
    # Run with: just -f ~/.agentboxes/justfile <command>
    # Or add alias: alias abx='just -f ~/.agentboxes/justfile'

    # Show available commands
    default:
        @just -f ~/.agentboxes/justfile --list

    # Install the full environment from agentbox.toml
    bootstrap:
        #!/usr/bin/env bash
        set -e
        echo "Installing agentbox environment..."
        cd ~/.agentboxes && nix profile install .#env --refresh
        # Extract store path and create usable symlink
        # nix-portable stores in ~/.nix-portable/nix/store/ but profile shows /nix/store/
        store_path=$(nix profile list 2>/dev/null | grep -oE '/nix/store/[a-z0-9]+-agentbox-env-[^[:space:]]+' | head -1)
        if [ -n "$store_path" ]; then
            real_path="$HOME/.nix-portable$store_path"
            if [ -d "$real_path/bin" ]; then
                ln -sfn "$real_path/bin" "$HOME/.agentbox-bin"
                echo "Linked tools to ~/.agentbox-bin"
            else
                echo "Warning: $real_path/bin not found"
            fi
        else
            echo "Warning: Could not find agentbox-env store path"
        fi
        echo ""
        echo "Bootstrap complete!"
        echo ""
        echo "To use your tools, either:"
        echo "  1. Start a new shell"
        echo "  2. Run: export PATH=~/.agentbox-bin:\$PATH"
        echo ""
        echo "Commands: just -f ~/.agentboxes/justfile [bootstrap|update|status|clean|nuke]"
        echo "Or add to your .bashrc: alias abx='just -f ~/.agentboxes/justfile'"

    # Update flake inputs and upgrade installed packages
    update:
        #!/usr/bin/env bash
        set -e
        echo "Updating agentbox environment..."
        cd ~/.agentboxes && nix flake update
        nix profile upgrade '.*'
        # Re-link after upgrade
        store_path=$(nix profile list 2>/dev/null | grep -oE '/nix/store/[a-z0-9]+-agentbox-env-[^[:space:]]+' | head -1)
        if [ -n "$store_path" ]; then
            real_path="$HOME/.nix-portable$store_path"
            if [ -d "$real_path/bin" ]; then
                ln -sfn "$real_path/bin" "$HOME/.agentbox-bin"
            fi
        fi
        echo "Update complete!"

    # Enter a nix develop shell (alternative to direnv)
    shell:
        cd ~/.agentboxes && nix develop

    # Show installed agentbox packages
    status:
        #!/usr/bin/env bash
        echo "Agentbox status:"
        echo ""
        echo "Installed packages:"
        nix profile list 2>/dev/null | grep -E 'agentbox|env' || echo "  (none installed)"
        echo ""
        echo "Tools symlink: ~/.agentbox-bin"
        if [ -L "$HOME/.agentbox-bin" ]; then
            echo "  -> $(readlink ~/.agentbox-bin)"
            echo ""
            echo "Available tools (first 15):"
            ls ~/.agentbox-bin 2>/dev/null | head -15 | sed 's/^/  /'
        else
            echo "  (not linked - run: just -f ~/.agentboxes/justfile bootstrap)"
        fi

    # Soft clean: remove profile and symlink (keeps nix-portable cache)
    clean:
        #!/usr/bin/env bash
        echo "Cleaning agentbox profile..."
        nix profile remove '.*' 2>/dev/null || true
        rm -f ~/.agentbox-bin
        rm -f ~/.agentboxes-bootstrapped
        echo "Cleaned! Run 'just -f ~/.agentboxes/justfile bootstrap' to reinstall."
        echo "(nix-portable cache preserved - use 'nuke' for full reset)"

    # Full reset: remove everything including nix-portable cache
    nuke:
        #!/usr/bin/env bash
        echo "Removing ALL agentbox and nix-portable data..."
        rm -rf ~/.agentbox-bin
        rm -rf ~/.agentboxes-bootstrapped
        rm -rf ~/.nix-portable
        rm -rf ~/.nix-profile
        rm -rf ~/.local/state/nix
        echo ""
        echo "Nuked! To reinstall, run:"
        echo "  just -f ~/.agentboxes/justfile bootstrap"
  '';

  # Direnv hook for bash
  direnvHook = pkgs.writeText "direnv-hook.sh" ''
    # Enable direnv for automatic environment activation
    if command -v direnv &> /dev/null; then
      eval "$(direnv hook bash)"
    fi
  '';

  # PATH setup for agentbox tools
  # nix-portable's profile symlinks point to /nix/store which only exists in sandbox
  # We use ~/.agentbox-bin as a stable symlink to the real store path
  agentboxPath = pkgs.writeText "agentbox-path.sh" ''
    # Add agentbox tools to PATH
    if [ -d "$HOME/.agentbox-bin" ]; then
      export PATH="$HOME/.agentbox-bin:$PATH"
    fi
  '';

  # Auto-bootstrap script (runs on first shell if enabled)
  # Note: distrobox mounts host home, so /etc/skel is never copied automatically.
  # This script copies the skel files on first run before bootstrapping.
  autoBootstrapScript = pkgs.writeText "agentbox-bootstrap.sh" ''
    # Copy agentbox files from /etc/skel if they don't exist
    # (distrobox mounts host home, so skel isn't copied automatically)
    if [ ! -d "$HOME/.agentboxes" ] && [ -d /etc/skel/.agentboxes ]; then
      cp -r /etc/skel/.agentboxes "$HOME/.agentboxes"
    fi
    # Copy nix config for nix-portable
    if [ ! -d "$HOME/.config/nix" ] && [ -d /etc/skel/.config/nix ]; then
      mkdir -p "$HOME/.config"
      cp -r /etc/skel/.config/nix "$HOME/.config/nix"
    fi

    # Auto-bootstrap on first login
    if [ ! -f "$HOME/.agentboxes-bootstrapped" ] && [ -f "$HOME/.agentboxes/flake.nix" ]; then
      echo ""
      echo "    ___                  _   ___"
      echo "   / _ | ___ ____ ___  _| |_/ _ )___ __ __"
      echo "  / __ |/ _ \`/ -_) _ \\/ _  _/ _ / _ \\\\ \\ /"
      echo " /_/ |_|\\_  /\\__/_//_/\\____|___/\\___/_\\_\\"
      echo "        /___/"
      echo ""
      echo " First boot detected - installing environment..."
      echo " This may take a few minutes on first run."
      echo " (Using nix-portable - store in ~/.nix-portable)"
      echo ""
      if just -f "$HOME/.agentboxes/justfile" bootstrap; then
        touch "$HOME/.agentboxes-bootstrapped"
        # Source PATH immediately so tools are available in this session
        if [ -d "$HOME/.agentbox-bin" ]; then
          export PATH="$HOME/.agentbox-bin:$PATH"
        fi
      else
        echo ""
        echo " Bootstrap failed. To retry:"
        echo "   just -f ~/.agentboxes/justfile bootstrap"
        echo ""
      fi
    fi
  '';

  # Nix configuration for nix-portable
  # nix-portable reads from ~/.config/nix/nix.conf
  nixConf = pkgs.writeText "nix.conf" ''
    experimental-features = nix-command flakes
  '';

in pkgs.dockerTools.buildLayeredImage {
  name = imageName;
  tag = imageTag;
  fromImage = wolfiBaseImage;
  contents = [ bootstrapProfile nixWrapper ];

  config = {
    Cmd = [ "/usr/bin/bash" ];
    Env = [
      "PATH=/nix/profile/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      "TERM=xterm-256color"
      "LANG=en_US.UTF-8"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/";
    Labels = {
      "org.opencontainers.image.description" = "agentbox slim: ${imageName} (nix-portable bootstrap)";
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

    # Install nix-portable binary
    cp ${nixPortable} nix/profile/bin/nix-portable
    chmod +x nix/profile/bin/nix-portable

    # Ensure etc exists for our customizations
    mkdir -p etc

    # Set up /etc/skel for distrobox user creation
    mkdir -p etc/skel/.agentboxes
    mkdir -p etc/skel/.config/nix

    # Copy agentbox.toml
    cp ${depsPath} etc/skel/.agentboxes/agentbox.toml

    # Copy generated flake.nix
    cp ${generatedFlake} etc/skel/.agentboxes/flake.nix

    # Create .envrc for direnv
    echo "use flake" > etc/skel/.agentboxes/.envrc

    # Copy justfile into .agentboxes (run with: just -f ~/.agentboxes/justfile)
    cp ${justfileContent} etc/skel/.agentboxes/justfile

    # Nix configuration (nix-portable reads from ~/.config/nix/nix.conf)
    cp ${nixConf} etc/skel/.config/nix/nix.conf

    # SSL certificates (copy from nix cacert package)
    mkdir -p etc/ssl/certs
    cp ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/

    # Profile.d scripts for shell initialization
    mkdir -p etc/profile.d

    # Direnv hook
    cp ${direnvHook} etc/profile.d/direnv-hook.sh
    chmod +x etc/profile.d/direnv-hook.sh

    # Agentbox PATH setup (must run early, use 00- prefix)
    cp ${agentboxPath} etc/profile.d/00-agentbox-path.sh
    chmod +x etc/profile.d/00-agentbox-path.sh

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
    │  Slim Bootstrap Image (nix-portable)    │
    │  Run 'just bootstrap' to install tools  │
    │  https://github.com/farra/agentboxes    │
    └─────────────────────────────────────────┘

MOTD
  '';
}
