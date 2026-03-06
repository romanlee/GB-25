#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <command> [args ...]"
    exit 1
fi

IMAGE="${IMAGE:-reactant:latest}"

export JULIA_DEBUG="${JULIA_DEBUG:-Reactant,Reactant_jll}"
export XLA_REACTANT_GPU_MEM_FRACTION="${XLA_REACTANT_GPU_MEM_FRACTION:-0.9}"

# Important else XLA might hang indefinitely
unset no_proxy http_proxy https_proxy NO_PROXY HTTP_PROXY HTTPS_PROXY

podman-hpc run --rm --gpu \
    --env JULIA_DEBUG \
    --env JULIA_DEPOT_PATH \
    --env JULIA_LOAD_PATH \
    --env JULIA_PROJECT \
    --env XLA_FLAGS \
    --env XLA_REACTANT_GPU_MEM_FRACTION \
    --volume "${PWD}:${PWD}" \
    --workdir "${PWD}" \
    "${IMAGE}" "$@"
