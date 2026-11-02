# Container (`GB-25`)

Single multi-architecture (`linux/amd64`, `linux/arm64`) [`Containerfile`](Containerfile) published as `ghcr.io/prontolab/gb-25`.

## Baseline Branch (`marco/containers-baseline`)

This branch runs the Oct 6 package stack (`container/Manifest.toml`: Reactant 0.2.254 / `Reactant_jll` 0.0.371, Breeze 0.4.7, Oceananigans 0.106.6, the `Project.toml` and model source of `nesap-fom`) in the current container. Library updates belong on `marco/containers`, not here.

## Build & Push

Built on every push to this branch (and on manual dispatch) by [`.github/workflows/Container.yml`](../.github/workflows/Container.yml). The tag is `IMAGE_TAG` (`env:` at the top of the workflow, default `baseline`).

This publishes `ghcr.io/romanlee/gb-25:<IMAGE_TAG>` (multi-arch) and the Apptainer images `:<IMAGE_TAG>-sif-amd64` / `:<IMAGE_TAG>-sif-arm64` as ORAS artifacts (`apptainer pull oras://...`, or download the manifest's single layer blob). Local build: `./container/build.sh` (native arch, loaded into local Docker).

## NCCL

The image ships its own NCCL core (`libnccl2`, pinned by the `NCCL_VERSION` build arg) in `/opt/nccl/lib`, first on the image's `LD_LIBRARY_PATH`. It replaces the older `libnccl.so.2` bundled in `Reactant_jll`; no host NCCL is mounted.
