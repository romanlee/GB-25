#!/bin/bash

set -euxo pipefail

SCRIPT_DIR="$(realpath "${PWD}")"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
export WORKDIR="${REPO_ROOT}"
STAGE_ROOT=""

cleanup() {
    [[ -n "${STAGE_ROOT}" ]] && rm -rf "${STAGE_ROOT}"
}
trap cleanup EXIT

# build image
IMAGE="gb25"
TAG="latest"

# Work around xattr protocol errors by staging the build context in /tmp
STAGE_ROOT="$(mktemp -d /tmp/gb25-podman-build.XXXXXX)"
STAGE_REPO="${STAGE_ROOT}/GB-25"
mkdir -p "${STAGE_REPO}/container-perlmutter"
cp "${REPO_ROOT}/Manifest.toml" "${STAGE_REPO}/Manifest.toml"
cp "${REPO_ROOT}/Project.toml" "${STAGE_REPO}/Project.toml"
cp -r "${REPO_ROOT}/src" "${STAGE_REPO}/src"
cp -r "${REPO_ROOT}/ext" "${STAGE_REPO}/ext"
cp "${SCRIPT_DIR}/Containerfile" "${STAGE_REPO}/container-perlmutter/Containerfile"
cp "${SCRIPT_DIR}/LocalPreferences.toml" "${STAGE_REPO}/container-perlmutter/LocalPreferences.toml"

pushd "${STAGE_REPO}/container-perlmutter"
podman-hpc build --build-arg=DESTDIR="${WORKDIR}" -f Containerfile -t "${IMAGE}:${TAG}" ..
popd

# make image persistent on scratch
podman-hpc migrate "${IMAGE}:${TAG}"

echo
echo "SUCCESS! Image built and migrated."
echo
