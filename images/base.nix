# Base OCI image for agentboxes
#
# This image provides a minimal foundation suitable for:
# - distrobox containers (with `nix develop` workflow)
# - Direct container deployment
# - Base layer for orchestrator/agent images
#
# Build with: nix build .#base-image
# Load with: docker load < result
#
# For pre-built images with everything included (no nix develop needed),
# use the orchestrator-specific images: schmux-image, gastown-image, etc.

{ pkgs, substrate }:

pkgs.dockerTools.buildImage {
  name = "agentboxes-base";
  tag = "latest";

  # Copy substrate tools into the image
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = substrate ++ (with pkgs; [
      # Essential for container operation
      bashInteractive
      coreutils

      # Nix with flakes support
      nix
      cacert  # SSL certificates for downloading from caches
      git     # Required for flake fetching
    ]);
    pathsToLink = [ "/bin" "/etc" "/share" ];
  };

  # Configure for interactive use (distrobox compatibility)
  config = {
    Cmd = [ "/bin/bash" ];
    Env = [
      "PATH=/bin:/usr/bin"
      "TERM=xterm-256color"
      # SSL certificates for nix to access caches
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/";
  };

  # Set up nix configuration and directories
  extraCommands = ''
    # Create nix config with flakes enabled
    mkdir -p etc/nix
    cat > etc/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
sandbox = false
EOF

    # Create necessary directories
    mkdir -p tmp home root
    chmod 1777 tmp

    # Copy SSL certificates to standard location
    mkdir -p etc/ssl/certs
    cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > etc/ssl/certs/ca-bundle.crt
  '';
}
