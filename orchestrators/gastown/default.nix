# Gastown orchestrator
#
# Multi-agent convoy orchestrator. Uses beads from llm-agents.nix.
# Gastown itself is not yet in llm-agents.nix, so we package it here.
#
# This package is structured to be submittable to llm-agents.nix in the future.

{ pkgs, system, substrate ? [], beads }:

let
  version = "0.5.0";

  # Platform-specific binary info
  platformInfo = {
    "x86_64-linux" = {
      asset = "gastown_${version}_linux_amd64.tar.gz";
      hash = "sha256:438245c0ac91a42eead4a1b1b744b505a1f7042a274239e659980f67b7886780";
    };
    "aarch64-linux" = {
      asset = "gastown_${version}_linux_arm64.tar.gz";
      hash = "sha256:b3d57a3c80229079aeb236dc059b190fe40ee3229030ca4a43fc47f32bbd9145";
    };
    "x86_64-darwin" = {
      asset = "gastown_${version}_darwin_amd64.tar.gz";
      hash = "sha256:01d548058e7bf6bd2cb56d03d3a690f9ed4cb0e25a941a0e48724618c6f585e5";
    };
    "aarch64-darwin" = {
      asset = "gastown_${version}_darwin_arm64.tar.gz";
      hash = "sha256:4043e23d8beed28c09dffade011dcfaa7b56c3995746643e44ab86cb52393d46";
    };
  };

  info = platformInfo.${system} or (throw "Unsupported system: ${system}");

  # Runtime dependencies
  runtimeDeps = with pkgs; [ tmux git bash coreutils sqlite ];

  # Gastown-specific deps (not in substrate)
  gastownDeps = with pkgs; [ sqlite ];

  # The gastown package
  package = pkgs.stdenv.mkDerivation {
    pname = "gastown";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/steveyegge/gastown/releases/download/v${version}/${info.asset}";
      hash = info.hash;
    };

    nativeBuildInputs = [ pkgs.makeWrapper pkgs.gnutar pkgs.gzip ];

    unpackPhase = ''
      tar -xzf $src
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp gt $out/bin/
      chmod +x $out/bin/gt

      # Wrap binary with runtime deps and beads
      wrapProgram $out/bin/gt \
        --prefix PATH : ${pkgs.lib.makeBinPath (runtimeDeps ++ [ beads ])}

      runHook postInstall
    '';

    # For future llm-agents.nix submission
    passthru.category = "Workflow & Project Management";

    meta = with pkgs.lib; {
      description = "Gas Town - Multi-agent AI orchestration with convoy management";
      homepage = "https://github.com/steveyegge/gastown";
      license = licenses.mit;
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      platforms = builtins.attrNames platformInfo;
      mainProgram = "gt";
    };
  };

  # Shell for running gastown
  shell = pkgs.mkShell {
    packages = [ package beads ] ++ gastownDeps ++ substrate;

    shellHook = ''
      echo "gastown ${version} environment"
      echo "Run 'gt' to start Gas Town"
    '';
  };

in {
  inherit package shell;
}
