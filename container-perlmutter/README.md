# Container for use on NERSC Perlmutter

## Introduction

This directory contains the code to build a container for running the code on Perlmutter using `podman-hpc`.
It uses a single-stage build for simplicity, unlike on alps.

## Build and usage

On Perlmutter, first instantiate the GordonBell25 project, then run the following from `container-perlmutter/`:

```sh
sbatch ./build.sh
```

Before submitting, edit `build.sh` and set `#SBATCH --account=<NERSC_ACCOUNT>` to your allocation.

The image can also be built on an interactive node
```
bash ./build.sh > build.out
```
Note, however, it must be a gpu node to resolve CUDA dependencies. 

## Running on Perlmutter

To run the Perlmutter scaling tests in the containerized environment, run the following 
command from `sharding/`:

```
julia perlmutter_scaling_test_containerized.jl <problem script>
```

Optional image override:

```
GB25_CONTAINER_IMAGE=gb25:latest julia perlmutter_scaling_test_containerized.jl <problem script>
```

where `<problem script>` is e.g. `simple_sharding_problem.jl`.

## Acknowledgements

This containter setup is derived from that for the Alps sytem, due to Mosè Giordano (UCL).
All further complications are the fault of Roman Lee.
