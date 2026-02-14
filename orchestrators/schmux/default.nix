{ pkgs, system, substrate ? [], schmux-src }:

let
  version = schmux-src.shortRev or "unknown";

  # Build dashboard assets from source
  dashboardDist = pkgs.buildNpmPackage {
    pname = "schmux-dashboard";
    inherit version;

    src = "${schmux-src}/assets/dashboard";

    npmDepsHash = "sha256-oCWtgxngpMih8Sv39nN1jEfIAQjMJnzNrMdJgBE2t5g=";

    buildPhase = ''
      runHook preBuild
      npx vite build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/* $out/
      runHook postInstall
    '';

    dontNpmInstall = true;
  };

  # Runtime deps baked into the binary wrapper
  runtimeDeps = with pkgs; [ tmux git bash coreutils ];

  # Build schmux from source
  package = pkgs.buildGoModule {
    pname = "schmux";
    inherit version;

    src = schmux-src;

    vendorHash = "sha256-gPvwIAX1vVX676MYRS+nRnvLBz/P0K5JYo6oe48vnBc=";

    subPackages = [ "cmd/schmux" ];

    env.CGO_ENABLED = 0;

    ldflags = [
      "-s" "-w"
      "-X github.com/sergeknystautas/schmux/internal/version.Version=${version}"
    ];

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postInstall = ''
      # Install dashboard assets relative to binary
      # schmux looks for: <binary-dir>/../assets/dashboard/dist
      mkdir -p $out/assets/dashboard/dist
      cp -r ${dashboardDist}/* $out/assets/dashboard/dist/

      # Wrap binary with runtime deps
      wrapProgram $out/bin/schmux \
        --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
    '';

    passthru.category = "Workflow & Project Management";

    meta = with pkgs.lib; {
      description = "Multi-agent AI orchestration system using tmux";
      homepage = "https://github.com/sergeknystautas/schmux";
      license = licenses.mit;
      mainProgram = "schmux";
    };
  };

  # Shell for running schmux
  # Composes: substrate + schmux package
  shell = pkgs.mkShell {
    packages = [ package ] ++ substrate;

    shellHook = ''
      echo "schmux (${version}) environment"
      echo "Run 'schmux start' to start the daemon"
    '';
  };

in
{
  inherit package shell;
}
