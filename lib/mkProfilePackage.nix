# mkProfilePackage - Create a buildEnv from agentbox.toml
#
# This creates a profile package that can be installed via `nix profile install .#<name>-env`.
# Used by Containerfile-based image building for baking tools into OCI images.
#
# Usage:
#   mkProfilePackage {
#     inherit pkgs system substrate orchestrators llmAgentsPkgs nurPkgs;
#   } ./agentbox.toml
#
# Then: nix profile install .#schmux-env

{ pkgs, system, substrate ? [], orchestrators ? {}, llmAgentsPkgs ? {}, nurPkgs ? null }:

depsPath:

let
  parsed = import ./parseAgentboxConfig.nix {
    inherit pkgs system substrate orchestrators llmAgentsPkgs nurPkgs;
  } depsPath;

in pkgs.buildEnv {
  name = "agentbox-env-${parsed.imageName}";
  paths = parsed.allPackages;
  pathsToLink = [ "/bin" "/share" "/lib" ];
}
