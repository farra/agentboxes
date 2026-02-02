# Deployment Guide

This guide covers how to deploy agentboxes environments to servers, share them with teams, and set up CI/CD for automated image publishing.

## Deployment Options

| Method | Best For | Requires Nix? |
|--------|----------|---------------|
| Share agentbox.toml | Reproducible, customizable environments | Yes (recipient) |
| Container registry | Teams, production, fast onboarding | No (recipient) |
| distrobox.ini | Team onboarding, multiple containers | No (recipient) |
| Direct image transfer | Air-gapped environments | No (recipient) |

## Option 1: Share agentbox.toml

The most flexible approach - recipients build their own images.

### Sender

```bash
# Create and test your configuration
cat > agentbox.toml << 'EOF'
[orchestrator]
name = "schmux"

[bundles]
include = ["complete"]

[tools]
python = "3.12"
nodejs = "20"

[llm-agents]
include = ["claude-code"]
EOF

# Verify it works
nix develop
nix build .#image
```

### Recipient

```bash
# Initialize project
mkdir my-env && cd my-env
nix flake init -t github:farra/agentboxes#project

# Copy shared agentbox.toml
# ... paste or copy file ...

# Build and use
nix build .#image
docker load < result
distrobox create --image agentbox:latest --name dev
distrobox enter dev
```

**Pros**: Fully reproducible, customizable, no registry needed
**Cons**: Requires nix on recipient's machine

## Option 2: Container Registry

Build once, distribute everywhere. Best for teams and production.

### Publishing to GitHub Container Registry (ghcr.io)

```bash
# Build the image
nix build .#schmux-image
docker load < result

# Tag for registry
docker tag agentbox:latest ghcr.io/YOUR_ORG/agentbox-schmux:latest
docker tag agentbox:latest ghcr.io/YOUR_ORG/agentbox-schmux:$(date +%Y%m%d)

# Login and push
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
docker push ghcr.io/YOUR_ORG/agentbox-schmux:latest
docker push ghcr.io/YOUR_ORG/agentbox-schmux:$(date +%Y%m%d)
```

### Publishing to Docker Hub

```bash
docker tag agentbox:latest YOUR_USERNAME/agentbox-schmux:latest
docker login
docker push YOUR_USERNAME/agentbox-schmux:latest
```

### Recipient Usage

```bash
# No nix required!
distrobox create --image ghcr.io/YOUR_ORG/agentbox-schmux:latest --name schmux-box
distrobox enter schmux-box
schmux start
```

## Option 3: distrobox.ini for Teams

Define multiple containers in a single config file for easy team onboarding.

### Create distrobox.ini

```ini
# distrobox.ini - Team development environments

[schmux-box]
image=ghcr.io/yourorg/agentbox-schmux:latest
pull=true
init=false
start_now=false
# Optional: home=/path/to/isolated/home

[gastown-box]
image=ghcr.io/yourorg/agentbox-gastown:latest
pull=true
init=false

[ralph-box]
image=ghcr.io/yourorg/agentbox-ralph:latest
pull=true
init=false
```

### Team Member Setup

```bash
# One command creates all containers
distrobox assemble create --file distrobox.ini

# Use any environment
distrobox enter schmux-box
distrobox enter gastown-box
```

### Updating Team Environments

```bash
# Pull latest images and recreate
distrobox assemble rm --file distrobox.ini
distrobox assemble create --file distrobox.ini
```

## Option 4: Direct Image Transfer

For air-gapped environments or quick sharing without a registry.

### Sender

```bash
# Build and save
nix build .#schmux-image
docker load < result
docker save agentbox:latest | gzip > agentbox-schmux.tar.gz

# Transfer via scp, USB, etc.
scp agentbox-schmux.tar.gz server:/tmp/
```

### Recipient

```bash
# Load and use
gunzip -c /tmp/agentbox-schmux.tar.gz | docker load
distrobox create --image agentbox:latest --name schmux-box
distrobox enter schmux-box
```

## CI/CD: Automated Image Publishing

### GitHub Actions

Create `.github/workflows/images.yml`:

```yaml
name: Build and Publish Images

on:
  push:
    branches: [main]
    paths:
      - 'flake.nix'
      - 'flake.lock'
      - 'lib/**'
      - 'orchestrators/**'
      - 'agents/**'
  workflow_dispatch:

jobs:
  build-images:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    strategy:
      matrix:
        image: [schmux, gastown, openclaw, ralph]

    steps:
      - uses: actions/checkout@v4

      - uses: cachix/install-nix-action@v24
        with:
          nix_path: nixpkgs=channel:nixos-unstable
          extra_nix_config: |
            experimental-features = nix-command flakes

      - uses: cachix/cachix-action@v12
        with:
          name: your-cachix-cache  # Optional: speeds up builds
          authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'

      - name: Build ${{ matrix.image }} image
        run: nix build .#${{ matrix.image }}-image

      - name: Load image
        run: docker load < result

      - name: Login to ghcr.io
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Push image
        run: |
          docker tag agentbox:latest ghcr.io/${{ github.repository }}/${{ matrix.image }}:latest
          docker tag agentbox:latest ghcr.io/${{ github.repository }}/${{ matrix.image }}:${{ github.sha }}
          docker push ghcr.io/${{ github.repository }}/${{ matrix.image }}:latest
          docker push ghcr.io/${{ github.repository }}/${{ matrix.image }}:${{ github.sha }}
```

### GitLab CI

Create `.gitlab-ci.yml`:

```yaml
stages:
  - build

.build-image:
  stage: build
  image: nixos/nix:latest
  before_script:
    - echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
  script:
    - nix build .#${IMAGE_NAME}-image
    - docker load < result
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker tag agentbox:latest $CI_REGISTRY_IMAGE/${IMAGE_NAME}:latest
    - docker push $CI_REGISTRY_IMAGE/${IMAGE_NAME}:latest

build-schmux:
  extends: .build-image
  variables:
    IMAGE_NAME: schmux

build-gastown:
  extends: .build-image
  variables:
    IMAGE_NAME: gastown
```

## Server Deployment

### Single Server with Distrobox

```bash
# On your build machine
nix build .#schmux-image
docker load < result
docker save agentbox:latest | ssh server 'docker load'

# On the server
ssh server
distrobox create --image agentbox:latest --name schmux-box
distrobox enter schmux-box
schmux start
```

### Multi-Orchestrator Setup

Run multiple orchestrators on one server using separate distrobox containers:

```bash
# Create containers for each orchestrator
distrobox create --image ghcr.io/org/schmux:latest --name schmux-box
distrobox create --image ghcr.io/org/gastown:latest --name gastown-box

# Each has isolated environment but shares $HOME
distrobox enter schmux-box   # Terminal 1
distrobox enter gastown-box  # Terminal 2
```

### Systemd Service (Optional)

For persistent orchestrators, create a systemd user service:

```ini
# ~/.config/systemd/user/schmux.service
[Unit]
Description=schmux orchestrator
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/distrobox-enter schmux-box -- schmux start --foreground
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable schmux
systemctl --user start schmux
```

## Best Practices

### Image Versioning

Always tag with both `latest` and a specific version:

```bash
docker tag agentbox:latest ghcr.io/org/schmux:latest
docker tag agentbox:latest ghcr.io/org/schmux:2024.01.15
docker tag agentbox:latest ghcr.io/org/schmux:$(git rev-parse --short HEAD)
```

### Security

- Use private registries for proprietary configurations
- Scan images before deploying: `docker scan ghcr.io/org/schmux:latest`
- Pin to specific versions in production distrobox.ini files

### Caching

Use Cachix to speed up Nix builds in CI:

```bash
# Setup (one-time)
cachix use nix-community
cachix authtoken YOUR_TOKEN

# In CI, builds will use cached derivations
```

## Troubleshooting

### Image won't load

```bash
# Check the result is a valid tarball
file result
# Should show: result: symbolic link to /nix/store/...-docker-image-agentbox.tar.gz

# Load with verbose output
docker load -i result
```

### distrobox can't find image

```bash
# Verify image is loaded
docker images | grep agentbox

# Check image name matches exactly
distrobox create --image agentbox:latest --name test
```

### Registry push fails

```bash
# Verify authentication
docker login ghcr.io

# Check image tag format
# Must be: registry/namespace/image:tag
docker tag agentbox:latest ghcr.io/YOUR_ORG/agentbox-schmux:latest
```
