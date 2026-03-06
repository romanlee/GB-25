#!/bin/bash

#SBATCH --job-name="build-container"
#SBATCH --time="1:00:00"
#SBATCH --output=build-container-%j.out
#SBATCH --error=build-container-%j.err
#SBATCH --nodes=1
#SBATCH --gpus-per-node=4
#SBATCH --gpu-bind=per_task:4
#SBATCH --constraint=gpu
#SBATCH --qos=regular
#SBATCH --account=m5176
#SBATCH --exclusive

set -euxo pipefail

if [[ "${@}" != "all" ]] &&  [[ "${@}" != "base" ]] && [[ "${@}" != "final" ]]; then
    echo "Must pass one of the arguments 'all', 'base' or 'final', got '${@}'"
    exit 1
fi

BASE_IMAGE="gb25-reactant-base"
BASE_TAG="latest"

if [[ "${@}" == "all" ]] || [[ "${@}" == "base" ]]; then

    # Here we build the base image, which takes more time and should be done
    # less frequently.

    podman-hpc build -f Containerfile-base -t "${BASE_IMAGE}:${BASE_TAG}" .

    echo "SUCCESS! Base image built."

fi

if [[ "${@}" == "all" ]] || [[ "${@}" == "final" ]]; then

    IMAGE="reactant"
    TAG="latest"
    SCRIPT_DIR="$(realpath "${PWD}")"
    REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
    export WORKDIR="${REPO_ROOT}"

    # Work around xattr protocol errors by staging the build context in /tmp.
    STAGE_ROOT="$(mktemp -d /tmp/gb25-podman-build.XXXXXX)"
    trap 'rm -rf "${STAGE_ROOT}"' EXIT
    STAGE_REPO="${STAGE_ROOT}/GB-25"
    mkdir -p "${STAGE_REPO}/container-perlmutter"
    cp "${REPO_ROOT}/Manifest.toml" "${STAGE_REPO}/Manifest.toml"
    cp "${REPO_ROOT}/Project.toml" "${STAGE_REPO}/Project.toml"
    cp -r "${REPO_ROOT}/src" "${STAGE_REPO}/src"
    cp -r "${REPO_ROOT}/ext" "${STAGE_REPO}/ext"
    cp "${SCRIPT_DIR}/Containerfile" "${STAGE_REPO}/container-perlmutter/Containerfile"
    cp "${SCRIPT_DIR}/LocalPreferences.toml" "${STAGE_REPO}/container-perlmutter/LocalPreferences.toml"

    pushd "${STAGE_REPO}/container-perlmutter"
    podman-hpc build --build-arg=DESTDIR="${WORKDIR}" --build-arg=BASE_IMAGE_TAG="${BASE_IMAGE}:${BASE_TAG}" -f Containerfile -t "${IMAGE}:${TAG}" ..
    popd

    # Required for images built on login nodes to be available on compute nodes.
    podman-hpc migrate "${IMAGE}:${TAG}"

    echo "SUCCESS! Final image built and migrated."
fi
