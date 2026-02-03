# justfile - agentboxes build commands

registry := "ghcr.io/farra"
flake_url := "github:farra/agentboxes"
base_image := "ghcr.io/ublue-os/wolfi-toolbox:latest"
runtime := `command -v podman 2>/dev/null || command -v docker 2>/dev/null || echo "no-runtime"`

default:
    @just --list

# List available orchestrators
list:
    @echo "Available orchestrators: schmux, gastown, openclaw, ralph"

# === Image Building ===

# Build an OCI image for an orchestrator
build-image name:
    {{runtime}} build \
        --build-arg ENV_NAME={{name}} \
        --build-arg FLAKE_URL={{flake_url}} \
        --build-arg BASE_IMAGE={{base_image}} \
        -t {{registry}}/agentboxes-{{name}}:latest \
        -f images/Containerfile .

# Tag an image with a version
tag-image name version:
    {{runtime}} tag {{registry}}/agentboxes-{{name}}:latest {{registry}}/agentboxes-{{name}}:{{version}}

# === Registry Operations ===

# Push latest image to registry
push-image name:
    {{runtime}} push {{registry}}/agentboxes-{{name}}:latest

# Push versioned image to registry
push-version name version:
    {{runtime}} push {{registry}}/agentboxes-{{name}}:{{version}}

# Build, tag, and push a release
release name version: (build-image name) (tag-image name version)
    {{runtime}} push {{registry}}/agentboxes-{{name}}:latest
    {{runtime}} push {{registry}}/agentboxes-{{name}}:{{version}}

# === Local Testing with Distrobox ===

# Create a distrobox from an image
distrobox-create name:
    distrobox create --image {{registry}}/agentboxes-{{name}}:latest --name {{name}}

# Enter a distrobox
distrobox-enter name:
    distrobox enter {{name}}

# Remove a distrobox
distrobox-rm name:
    distrobox rm {{name}} --force

# Build image and create distrobox for local testing
test-local name: (build-image name) (distrobox-create name)
    @echo "Created distrobox '{{name}}'. Enter with: just distrobox-enter {{name}}"

# === Development ===

# Enter a nix develop shell
dev name:
    nix develop .#{{name}}

# Build a nix package
build name:
    nix build .#{{name}}

# Build an -env profile package
build-env name:
    nix build .#{{name}}-env

# Run nix flake check
check:
    nix flake check
