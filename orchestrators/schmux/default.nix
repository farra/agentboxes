{ pkgs, system, substrate ? [] }:

let
  version = "1.1.1";

  # Platform-specific binary info
  platformInfo = {
    "x86_64-linux" = {
      name = "schmux-linux-amd64";
      sha256 = "927bf9c92ddeab315114ba7418f0dbe691bb0179ee03f95370c93164bc6217af";
    };
    "aarch64-linux" = {
      name = "schmux-linux-arm64";
      sha256 = "af9a89b3c43a24b766f029531d1aeaef5adb8c6edc1c329ba6750ec6faadb7a0";
    };
    "x86_64-darwin" = {
      name = "schmux-darwin-amd64";
      sha256 = "95d19e1bccfe1a2654ce6cd2b91831234caf0d3a711e72e49da9b0c831c63088";
    };
    "aarch64-darwin" = {
      name = "schmux-darwin-arm64";
      sha256 = "cb69e0dbc5dc8c749f081d5e2d3dfacc08163a1a37db73fb60af4ccefe0bb0f5";
    };
  };

  info = platformInfo.${system} or (throw "Unsupported system: ${system}");

  # Fetch the pre-built binary
  binary = pkgs.fetchurl {
    url = "https://github.com/sergeknystautas/schmux/releases/download/v${version}/${info.name}";
    sha256 = info.sha256;
  };

  # Fetch dashboard assets
  dashboardAssets = pkgs.fetchurl {
    url = "https://github.com/sergeknystautas/schmux/releases/download/v${version}/dashboard-assets.tar.gz";
    sha256 = "c77175edee07dd16698964bf5d000f497677291bd8573e750d60ce52f1e591c0";
  };

  # Schmux-specific runtime dependencies (not in substrate)
  # Note: tmux, git, bash, coreutils are now provided by substrate
  schmuxDeps = with pkgs; [];

  # Combined runtime deps for the package wrapper
  # These are baked into the binary wrapper for standalone use
  runtimeDeps = with pkgs; [ tmux git bash coreutils ];

  # The schmux package
  package = pkgs.stdenv.mkDerivation {
    pname = "schmux";
    inherit version;

    dontUnpack = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      # Install binary
      mkdir -p $out/bin
      cp ${binary} $out/bin/schmux
      chmod +x $out/bin/schmux

      # Install dashboard assets relative to binary
      # schmux looks for: <binary-dir>/../assets/dashboard/dist
      mkdir -p $out/assets/dashboard/dist
      tar -xzf ${dashboardAssets} -C $out/assets/dashboard/dist

      # Wrap binary with runtime deps
      wrapProgram $out/bin/schmux \
        --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}

      runHook postInstall
    '';

    # For future llm-agents.nix submission
    passthru.category = "Workflow & Project Management";

    meta = with pkgs.lib; {
      description = "Multi-agent AI orchestration system using tmux";
      homepage = "https://github.com/sergeknystautas/schmux";
      license = licenses.mit;
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      platforms = builtins.attrNames platformInfo;
      mainProgram = "schmux";
    };
  };

  # Shell for running schmux
  # Composes: substrate + schmux package + schmux-specific deps
  shell = pkgs.mkShell {
    packages = [ package ] ++ schmuxDeps ++ substrate;

    shellHook = ''
      echo "schmux ${version} environment"
      echo "Run 'schmux start' to start the daemon"
    '';
  };

in
{
  inherit package shell;
}
