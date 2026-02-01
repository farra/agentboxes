# OpenClaw orchestrator environment
#
# Unlike schmux/gastown (pre-built Go binaries), OpenClaw is an npm package
# with native dependencies. We provide the Node.js runtime and let users
# install via npm.
#
# Usage:
#   nix develop .#openclaw
#   npm install -g openclaw@latest
#   openclaw onboard --install-daemon

{ pkgs, system, substrate ? [] }:

let
  # OpenClaw requires Node.js >= 22.12.0
  nodejs = pkgs.nodejs_22;

  # OpenClaw-specific runtime dependencies
  openclawDeps = with pkgs; [
    nodejs
    nodePackages.pnpm
    # Native build dependencies for npm packages
    python3          # node-gyp
    pkg-config
    # For sharp (image processing)
    vips
    # For sqlite-vec
    sqlite
    # For playwright
    # (playwright manages its own browsers)
  ];

  # Shell for running openclaw
  # Composes: substrate + openclaw deps
  shell = pkgs.mkShell {
    packages = openclawDeps ++ substrate;

    shellHook = ''
      echo "openclaw environment (Node.js ${nodejs.version})"
      echo ""
      if command -v openclaw &> /dev/null; then
        echo "openclaw is installed: $(openclaw --version 2>/dev/null || echo 'run openclaw --version')"
      else
        echo "To install openclaw:"
        echo "  npm install -g openclaw@latest"
        echo ""
        echo "Then run onboarding:"
        echo "  openclaw onboard --install-daemon"
      fi
    '';
  };

in
{
  inherit shell;
  # No pre-built package - users install via npm
  package = null;
}
