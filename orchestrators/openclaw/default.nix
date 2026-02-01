# OpenClaw orchestrator environment
#
# Unlike schmux/gastown (pre-built Go binaries), OpenClaw is an npm package
# with native dependencies. We auto-install to a local prefix on first use.
#
# Usage:
#   nix develop .#openclaw
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
      # Use a local npm prefix to avoid system pollution
      export NPM_CONFIG_PREFIX="$HOME/.local/share/agentboxes/openclaw"
      export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

      echo "openclaw environment (Node.js ${nodejs.version})"

      # Check if openclaw is installed, install if not
      if command -v openclaw &> /dev/null; then
        echo "openclaw $(openclaw --version 2>/dev/null || echo 'installed')"
      else
        echo "Installing openclaw..."
        mkdir -p "$NPM_CONFIG_PREFIX"
        npm install -g openclaw@latest
        echo ""
        echo "openclaw installed. Run 'openclaw onboard' to get started."
      fi
    '';
  };

in
{
  inherit shell;
  # No pre-built package - installed via npm in shellHook
  package = null;
}
