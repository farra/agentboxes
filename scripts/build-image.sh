#!/usr/bin/env bash
# Build an agentboxes OCI image using Containerfile
#
# Usage:
#   ./scripts/build-image.sh schmux
#   ./scripts/build-image.sh gastown --push
#   ENV_NAME=ralph ./scripts/build-image.sh
#
# Environment variables:
#   ENV_NAME      - Environment to build (schmux, gastown, openclaw, ralph)
#   REGISTRY      - Container registry (default: ghcr.io/farra)
#   BASE_IMAGE    - Base image override
#   FLAKE_URL     - Flake URL override (default: github:farra/agentboxes)

set -euo pipefail

# Defaults
ENV_NAME="${1:-${ENV_NAME:-schmux}}"
REGISTRY="${REGISTRY:-ghcr.io/farra}"
FLAKE_URL="${FLAKE_URL:-github:farra/agentboxes}"
BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ublue-os/wolfi-toolbox:latest}"
PUSH="${2:-}"

IMAGE_NAME="${REGISTRY}/agentboxes-${ENV_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Building agentboxes image: ${IMAGE_NAME}"
echo "  ENV_NAME:   ${ENV_NAME}"
echo "  FLAKE_URL:  ${FLAKE_URL}"
echo "  BASE_IMAGE: ${BASE_IMAGE}"
echo ""

# Detect container runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo "Error: Neither podman nor docker found in PATH"
    exit 1
fi

echo "Using container runtime: ${RUNTIME}"

# Build the image
${RUNTIME} build \
    --build-arg ENV_NAME="${ENV_NAME}" \
    --build-arg FLAKE_URL="${FLAKE_URL}" \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    -t "${IMAGE_NAME}:latest" \
    -f "${PROJECT_ROOT}/images/Containerfile" \
    "${PROJECT_ROOT}"

echo ""
echo "Built: ${IMAGE_NAME}:latest"

# Push if requested
if [[ "${PUSH}" == "--push" ]]; then
    echo "Pushing to registry..."
    ${RUNTIME} push "${IMAGE_NAME}:latest"
    echo "Pushed: ${IMAGE_NAME}:latest"
fi

echo ""
echo "To use with distrobox:"
echo "  distrobox create --image ${IMAGE_NAME}:latest --name ${ENV_NAME}"
echo "  distrobox enter ${ENV_NAME}"
