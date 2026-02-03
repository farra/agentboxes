# Distros

Pre-configured `agentbox.toml` files for each orchestrator. These drive both `nix develop` shells and Containerfile-based OCI image builds.

## Available Distros

| Distro | Orchestrator | Agents | Packages |
|--------|--------------|--------|----------|
| `schmux` | schmux | claude-code | python, nodejs |
| `gastown` | gastown | claude-code | python, nodejs, go |
| `openclaw` | openclaw | claude-code | nodejs, pnpm |
| `ralph` | ralph | claude-code | python, nodejs |

All distros include the `baseline` tool bundle.

## Usage

### Build an OCI image

```bash
# Using justfile (recommended)
just build-image schmux

# Or manually with podman/docker
podman build --build-arg ENV_NAME=schmux -t agentboxes-schmux images/
```

### Use with distrobox

```bash
# Build and create in one step
just test-local schmux

# Or step by step:
just build-image schmux
distrobox create --image ghcr.io/farra/agentboxes-schmux:latest --name schmux
distrobox enter schmux
```

### Use for local development

```bash
# Enter a devShell directly (no container needed)
nix develop github:farra/agentboxes#schmux
```

### Copy to your project

```bash
# Initialize a project
mkdir my-project && cd my-project
nix flake init -t github:farra/agentboxes#project

# Optionally replace default config with a distro
curl -O https://raw.githubusercontent.com/farra/agentboxes/main/distros/schmux.toml
mv schmux.toml agentbox.toml

# Use it
nix develop
```

## Creating Custom Distros

Copy any distro file and customize:

```toml
# my-custom.toml
agents = ["claude-code", "codex", "gemini-cli"]
bundles = ["complete", "rust-stable"]
packages = ["python312", "nodejs_22", "go_1_24"]

[image]
name = "my-custom"
tag = "latest"
base = "wolfi"

[orchestrator]
name = "schmux"
```

Build your custom image:

```bash
podman build \
  --build-arg ENV_NAME=my-custom \
  --build-arg FLAKE_URL=. \
  -t my-custom-image \
  -f images/Containerfile .
```

## Profile Packages

Each distro also produces a profile package for `nix profile install`:

```bash
# Build the profile package
nix build .#schmux-env

# Install to your profile (outside of containers)
nix profile install .#schmux-env
```

This is what the Containerfile uses internally to bake tools into images.
