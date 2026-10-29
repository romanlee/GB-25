#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

docker buildx bake -f container/docker-bake.hcl "$@"
