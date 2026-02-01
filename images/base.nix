# Base OCI image for agentboxes
#
# This image provides a minimal foundation suitable for:
# - distrobox containers
# - Direct container deployment
# - Base layer for orchestrator/agent images
#
# Build with: nix build .#base-image
# Load with: docker load < result

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
      nix
    ]);
    pathsToLink = [ "/bin" "/etc" "/share" ];
  };

  # Configure for interactive use (distrobox compatibility)
  config = {
    Cmd = [ "/bin/bash" ];
    Env = [
      "PATH=/bin:/usr/bin"
      "TERM=xterm-256color"
    ];
    WorkingDir = "/";
  };

  # Enable running as non-root
  runAsRoot = ''
    #!${pkgs.runtimeShell}
    mkdir -p /tmp /home /root
    chmod 1777 /tmp
  '';
}
