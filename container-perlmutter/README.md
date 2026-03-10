# Container for use on NERSC Perlmutter

## Introduction

This directory contains the code to build a container for running the code on Perlmutter using `podman-hpc`.
It keeps the same two-stage flow as `container-alps/`:

* first a "base" container, which takes longer to build.
* the "final" container, based on "base", which uses the local environment, to reflect local changes.

After building the final image, we run `podman-hpc migrate` so the image is usable on compute nodes.

## Build and usage

On Perlmutter, run the following from `container-perlmutter/`:

```sh
sbatch ./build.sh <image type>
```

where `<image type>` is one of

* `base`, for building the "base" image locally,
* `final`, for building the "final" image and migrating it for `podman-hpc` runtime on compute nodes.
  If you use this option make sure you have a reasonably recent base image already built
* `all` to build both images in the same job.

Before submitting, edit `build.sh` and set `#SBATCH --account=<NERSC_ACCOUNT>` to your allocation.

The image can also be built on an interactive node (`bash ./build.sh <image type>`). 
Note, however, it must be a gpu node to resolve CUDA dependencies. 

## Running on Perlmutter

To run the Perlmutter scaling tests in the containerized environment, run the following 
command from `sharding/`:

```
julia perlmutter_scaling_test_containerized.jl <problem script>
```

Optional image override:

```
GB25_CONTAINER_IMAGE=reactant:latest julia perlmutter_scaling_test_containerized.jl <problem script>
```

where `<problem script>` is e.g. `simple_sharding_problem.jl`.

## Acknowledgements

This containter setup is derived from that for the Alps sytem, due to Mosè Giordano (UCL).
All further complications are the fault of Roman Lee.
