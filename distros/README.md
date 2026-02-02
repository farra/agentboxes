# Distros

Pre-configured agentbox.toml files for common use cases. Each distro is a complete, ready-to-use configuration.

## Available Distros

| Distro | Orchestrator | Agents | Runtimes |
|--------|--------------|--------|----------|
| `schmux-full` | schmux | claude, gemini, codex, opencode | python, nodejs, go, rust |
| `gastown-full` | gastown | claude, gemini, codex, opencode | python, nodejs, go, rust |
| `openclaw-full` | openclaw | claude, gemini, codex, opencode | python, nodejs, go, rust |
| `ralph-full` | ralph | claude-code only | python, nodejs, go, rust |

All distros include the `complete` tool bundle (61 CLI tools).

## Usage

### Build a pre-built image

```bash
nix build github:farra/agentboxes#schmux-image
docker load < result
```

### Copy to your project

```bash
# Initialize a project
mkdir my-project && cd my-project
nix flake init -t github:farra/agentboxes#project

# Replace the default config with a distro
curl -O https://raw.githubusercontent.com/farra/agentboxes/main/distros/schmux-full.toml
mv schmux-full.toml agentbox.toml

# Use it
nix develop
```

### Use with distrobox

```bash
nix build github:farra/agentboxes#schmux-image
docker load < result
distrobox create --image agentbox:latest --name schmux-dev
distrobox enter schmux-dev
```

## Why "full"?

The `-full` suffix indicates these distros include:
- All common language runtimes (Python, Node.js, Go, Rust)
- The complete tool bundle (not just baseline)
- All applicable AI coding agents for that orchestrator

For minimal configurations, use the basic `nix develop .#schmux` shell or create your own agentbox.toml.
