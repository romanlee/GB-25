# Container (`GB-25`)

Single multi-architecture (`linux/amd64`, `linux/arm64`) [`Containerfile`](Containerfile) published by CI to the GitHub Container Registry of the repository it runs in.

## Build & Push

Built on every push (and on manual dispatch) by [`.github/workflows/Container.yml`](../.github/workflows/Container.yml). The tag is `IMAGE_TAG`, set in the `env:` at the top of the workflow.

This publishes `ghcr.io/<owner>/gb-25:<IMAGE_TAG>` (multi-arch) and the Apptainer images `:<IMAGE_TAG>-sif-amd64` / `:<IMAGE_TAG>-sif-arm64` as ORAS artifacts (`apptainer pull oras://...`, or download the manifest's single layer blob). Local build: `./container/build.sh` (native arch, loaded into local Docker).

## NCCL

The image ships its own NCCL core (`libnccl2`, pinned by the `NCCL_VERSION` build arg) in `/opt/nccl/lib`, first on the image's `LD_LIBRARY_PATH`. It replaces the older `libnccl.so.2` bundled in `Reactant_jll`; no host NCCL is mounted.
