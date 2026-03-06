# Container for use on NERSC Perlmutter

## Introduction

This directory contains the code to build a container for running the code on Perlmutter using `podman-hpc`.
It keeps the same two-stage flow as `container-alps`:

* first a "base" container, which takes longer to build, and is kept locally.
* the "final" container, based on the previous one, which uses the local environment, to reflect local changes.

After building the final image, we run `podman-hpc migrate` so the image is usable on compute nodes.

## Build and usage

On Perlmutter, enter this directory and run:

```sh
sbatch ./build.sh <image type>
```

where `<image type>` is one of

* `base`, for building the "base" image locally,
* `final`, for building the "final" image and migrating it for `podman-hpc` runtime on compute nodes.
  If you use this option make sure you have a reasonably recent local base image already built
* `all` to build both images in the same job.

Note: the `final` build path stages a temporary build context in `/tmp` to avoid
`podman-hpc` xattr-related `COPY` failures on some filesystems.

Before submitting, edit `build.sh` and set `#SBATCH --account=<NERSC_ACCOUNT>` to your allocation.

If you want to submit the job to the debug queue:

```sh
sbatch --qos=debug --time='00:30:00' ./build.sh <image type>
```

## Running on Perlmutter

`podman-hpc` does not enable GPU or MPI integration by default.
This setup intentionally keeps MPI off.

Use the wrapper:

```sh
./run.sh julia --project=/global/u1/r/romanlee/codes/GB-25 simulations/baroclinic_instability_simulation_run.jl
```

or call `podman-hpc` directly:

```sh
podman-hpc run --rm --gpu reactant:latest <command>
```

  Usage:

  cd sharding
  julia perlmutter_scaling_test_containerized.jl simple_sharding_problem.jl

  Optional image override:

  GB25_CONTAINER_IMAGE=reactant:latest julia perlmutter_scaling_test_containerized.jl simple_sharding_problem.jl

## Acknowledgements

Thanks to Theofilos Manitaras (CSCS) for providing a first draft of the container setup.
All further complications are by Mosè Giordano (UCL).
