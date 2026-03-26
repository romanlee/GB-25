# GB-25

This repository accompanies a submission for the 2025 Gordon Bell climate prize submission that showcases Reactant-acceleration of Oceananigans, ClimaOcean, and SpeedyWeather simulations.

## TODO/current status

GB25 perlmutter container TODO (See perlmutter `~/scratch-backups/2026.03.26/GB25/2026.03.20.container-debug` for latest debug runs)
* more robust way to do env flags, `--env-file`
* julia 11.9
* gdrcopy: do we actually need? How to get working on pm.
* make sure versions of everything (LocalPreferences.toml) are what they should be. Eg, seem to be mixing cuda 12.8 and 13.0 (but maybe this one's fine)
* pm julia has some special localpreferences.toml files to configure eg MPI prefs given your
  module loads. Do we need those in the container?
* one of the main motivations of containers for julia is not haveing to rebuild every time on distributed nodes. Verify this.
* get the container build to fail if I get an error when building the jluia stuff (to get it to fail, set the reactant jll cuda version to 13.0)
* validate performance

## Package organization

* `src` implements two models:
    * `GordonBell25.data_free_climate_simulation_init`, which uses ClimaOcean to drive an Oceananigans `HydrostaticFreeSurfaceModel`
    * `GordonBell25.baroclinic_instability_model`, a simpler, unforced, pure Oceananigans setup.
    * Both models can be to use either a `LatitudeLongitudeGrid` or a `TripolarGrid` with idealized bathymetry.

* `simulations`: scripts to i) compile and ii) run either of the two models

* `sharding`: scripts and utilities that use XLA's sharding to distribute computations across multiple nodes. Oceananigans uses its `Distributed` architecture to represent sharding across nodes.

* `ext`: many small packages that each precompile part of a model time-step, in order to accelerate compilation during intensive jobs.

## Running scaling benchmarks

Initial setup:

* If you haven't already, install Julia following the instructions on the [official website](https://julialang.org/downloads/).
  Julia may (or may not!) be available on the system you use, check that first too
* Enter the directory and precompile the environment with
  ```
  julia --project -e 'using Pkg; Pkg.instantiate()'
  ```
  This step will take a few minutes, but should be needed only the first time (or any time you want to update the package)

We have some scripts which use sharding in the [`sharding/`](./sharding) directory.
If you have multiple devices available locally, you may be able to launch a simple problem locally.
To do this, you first must comment out `Reactant.Distributed.initialize()` in `sharding/simple_sharding_problem.jl`.
Next, enter `sharding/` and type
```
julia --project -O0 simple_sharding_problem.jl
```
(If you do not have multiple devices availalbe and you are using a CPU, add the flag `XLA_FLAGS="--xla_force_host_platform_device_count=4"` to
trick XLA into thinking that you have 4 individual devices available, for example.)
On systems we tested this application (Alps @ CSCS, Leonardo @ CINECA, Perlmutter @ NERSC) we provide some script to automatically submit scaling jobs that you can run with (need to be again inside the sharding directory, and in this case you do ***not*** need to comment out `Reactant.Distributed.initialize()`)
```
julia alps_scaling_test.jl simple_sharding_problem.jl
julia leonardo_scaling_test.jl simple_sharding_problem.jl
julia perlmutter_scaling_test.jl simple_sharding_problem.jl
```
You'll need to tweak the content of the scaling test scripts to what you need, e.g. change `submit` to `true` to actuallt run the jobs, `time` to the walltime requested for the job, `Ngpus` for the number of GPUs you want to run on (note that that's number of GPUs , not nodes!), etc., have a look at the script for your system.

> [!NOTE]
> Note that on Alps @ CSCS one needs to first load the Julia uenv
> ```
> uenv start --view=juliaup,modules julia/25.5:v1
> ```
> and set the following if precompilation fails because of `/usr/lib64/libcrypto.so.3: version `OPENSSL_3.3.0' not found`:
> ```
> export LD_PRELOAD=/capstor/scratch/cscs/lraess/.julia/gh200/juliaup/depot/artifacts/152ab7c1cf7e3e69c2fa76110b9e01affcbb1f36/lib/libcrypto.so.3
> ```
