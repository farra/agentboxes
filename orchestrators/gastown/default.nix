{ pkgs, system, substrate ? [] }:

let
  gastownVersion = "0.5.0";
  beadsVersion = "0.49.3";

  # Platform-specific binary info for gastown
  gastownPlatformInfo = {
    "x86_64-linux" = {
      name = "gastown_${gastownVersion}_linux_amd64.tar.gz";
      sha256 = "438245c0ac91a42eead4a1b1b744b505a1f7042a274239e659980f67b7886780";
    };
    "aarch64-linux" = {
      name = "gastown_${gastownVersion}_linux_arm64.tar.gz";
      sha256 = "b3d57a3c80229079aeb236dc059b190fe40ee3229030ca4a43fc47f32bbd9145";
    };
    "x86_64-darwin" = {
      name = "gastown_${gastownVersion}_darwin_amd64.tar.gz";
      sha256 = "01d548058e7bf6bd2cb56d03d3a690f9ed4cb0e25a941a0e48724618c6f585e5";
    };
    "aarch64-darwin" = {
      name = "gastown_${gastownVersion}_darwin_arm64.tar.gz";
      sha256 = "4043e23d8beed28c09dffade011dcfaa7b56c3995746643e44ab86cb52393d46";
    };
  };

  # Platform-specific binary info for beads
  beadsPlatformInfo = {
    "x86_64-linux" = {
      name = "beads_${beadsVersion}_linux_amd64.tar.gz";
      sha256 = "f84d534bd1c53f0dd404f4b86dc6678d26af712884658e1e43e7a6bb080b3124";
    };
    "aarch64-linux" = {
      name = "beads_${beadsVersion}_linux_arm64.tar.gz";
      sha256 = "0fdf33abf4bac10e302e1a99d6e2bad142b6640638622fd10bcb7c9348138676";
    };
    "x86_64-darwin" = {
      name = "beads_${beadsVersion}_darwin_amd64.tar.gz";
      sha256 = "9f2878c7553d32645f58fa74c4f9a1e45a868555e5d41a07342d63a0020ce265";
    };
    "aarch64-darwin" = {
      name = "beads_${beadsVersion}_darwin_arm64.tar.gz";
      sha256 = "b590f66f1e2a70e4dff7f499bfd2cd710ac03d0a97524ee84c2b1d28aee8492e";
    };
  };

  gastownInfo = gastownPlatformInfo.${system} or (throw "Unsupported system: ${system}");
  beadsInfo = beadsPlatformInfo.${system} or (throw "Unsupported system: ${system}");

  # Fetch gastown tarball
  gastownSrc = pkgs.fetchurl {
    url = "https://github.com/steveyegge/gastown/releases/download/v${gastownVersion}/${gastownInfo.name}";
    sha256 = gastownInfo.sha256;
  };

  # Fetch beads tarball
  beadsSrc = pkgs.fetchurl {
    url = "https://github.com/steveyegge/beads/releases/download/v${beadsVersion}/${beadsInfo.name}";
    sha256 = beadsInfo.sha256;
  };

  # Gastown-specific runtime dependencies (not in substrate)
  gastownDeps = with pkgs; [
    sqlite
  ];

  # Combined runtime deps for the package wrapper
  runtimeDeps = with pkgs; [ tmux git bash coreutils sqlite ];

  # The beads package (dependency for gastown)
  beads = pkgs.stdenv.mkDerivation {
    pname = "beads";
    version = beadsVersion;

    src = beadsSrc;

    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];

    unpackPhase = ''
      tar -xzf $src
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp bd $out/bin/
      chmod +x $out/bin/bd
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Beads work tracking system";
      homepage = "https://github.com/steveyegge/beads";
      license = licenses.mit;
      platforms = builtins.attrNames beadsPlatformInfo;
    };
  };

  # The gastown package
  package = pkgs.stdenv.mkDerivation {
    pname = "gastown";
    version = gastownVersion;

    src = gastownSrc;

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

    meta = with pkgs.lib; {
      description = "Gas Town - Multi-agent AI orchestration with convoy management";
      homepage = "https://github.com/steveyegge/gastown";
      license = licenses.mit;
      platforms = builtins.attrNames gastownPlatformInfo;
    };
  };

  # Shell for running gastown
  # Composes: substrate + gastown package + beads + gastown-specific deps
  shell = pkgs.mkShell {
    packages = [ package beads ] ++ gastownDeps ++ substrate;

    shellHook = ''
      echo "gastown ${gastownVersion} environment (beads ${beadsVersion})"
      echo "Run 'gt' to start Gas Town"
    '';
  };

in
{
  inherit package shell beads;
}
