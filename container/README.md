# Container (`GB-25`)

Single multi-architecture (`linux/amd64`, `linux/arm64`) [`Containerfile`](Containerfile) published as `ghcr.io/prontolab/gb-25:latest`.

## Build & Push

Built automatically via [`.github/workflows/Container.yml`](../.github/workflows/Container.yml), or manually via `docker buildx bake`:

```bash
./container/build.sh            # build multi-arch image
./container/build.sh --push     # build and push multi-arch manifest to $REGISTRY_IMAGE:latest
```
