# Container (`GB-25`)

Single multi-architecture (`linux/amd64`, `linux/arm64`) [`Containerfile`](Containerfile) published as `ghcr.io/prontolab/gb-25`.

## Build & Push

Built automatically via [`.github/workflows/Container.yml`](../.github/workflows/Container.yml), or manually via `docker buildx bake`:

```bash
./container/build.sh   # build native arch and load into local Docker
```

CI also publishes Apptainer images as ORAS artifacts `ghcr.io/prontolab/gb-25:sif-amd64` and `:sif-arm64` (`apptainer pull oras://...`, or download the manifest's single layer blob).

## NCCL

The image ships its own NCCL core (`libnccl2`, pinned by the `NCCL_VERSION` build arg) in `/opt/nccl/lib`, first on the image's `LD_LIBRARY_PATH`. It replaces the older `libnccl.so.2` bundled in `Reactant_jll`; no host NCCL is mounted.
