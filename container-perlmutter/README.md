# Perlmutter Container (`gb25:perlmutter`)

Self-contained container build for running `GordonBell25` scaling benchmarks on **NERSC Perlmutter** (`linux/amd64`, 4x NVIDIA A100-SXM4-40GB per node, HPE Slingshot-11 interconnect).

## What Is Inside the Container vs. From the Host

### Sealed Inside the Image
- **OS & Compiler Toolchain:** Ubuntu 24.04 (`glibc 2.39`, `libstdc++`, `libcrypto.so.3`, `gcc 13`, `binutils`).
- **CUDA & NCCL via Julia JLLs:** `Reactant_jll` (`gpu = "cuda"`, `gpu_version = "13.1"`) and `CUDA_Runtime_jll` (`version = "13.1"`) provide the complete CUDA 13.1 runtime/math libraries, `ptxas`, and `libnccl.so.2` (NCCL `2.27.7`) directly from the precompiled Julia depot.
- **GPUDirect RDMA & Profiling Tools:** `gdrcopy` (`libgdrapi.so` v2.4.4) and Nsight Systems CLI (`nsys`).
- **MPI ABI Baseline:** Ubuntu `mpich` (`libmpi.so.12`), ABI-compatible with Cray MPICH.
- **Julia & Precompiled Environment:** Julia `1.11.9` (`/usr/local/julia/bin/julia`), the `GB-25` source repository at `/opt/gb25`, and a fully instantiated + `-O0` precompiled depot at `/usr/local/share/julia_depot` (`JULIA_CPU_TARGET=generic`, `REACTANT_GPU=cuda`, `REACTANT_GPU_VERSION=13.1`).

### Injected from the Host at Runtime (`podman-hpc`)
- **`--gpu`:** Host kernel driver libraries (`libcuda.so.1`, `libnvidia-ml.so.1`) matching `/dev/nvidia*`.
- **`--nccl`:** NERSC `aws-ofi-nccl` (`libnccl-net.so`) and HPE Slingshot `libfabric.so` / `libcxi.so` so `Reactant_jll`'s `libnccl.so.2` runs over Slingshot RDMA + GPUDirect RDMA.
- **`--mpi`:** Cray MPICH (`libmpi.so.12`) and Slurm PMI2/PMIx hooks for native Slingshot MPI.
- **`-v $SCRATCH:$SCRATCH`:** Writable scratch filesystem for job scripts, logs, and profiler outputs. Each rank writes its runtime Julia/XLA scratch cache to node-local RAM (`/tmp/gb25_depot_${SLURM_JOB_ID}_${SLURM_PROCID}`).

## Build

From the root of `GB-25` (or via `../build.sh` in the campaign directory):

```bash
podman build --platform linux/amd64 -t gb25:perlmutter -f container-perlmutter/Containerfile .
```

On Perlmutter (`podman-hpc`), pull or build the image and run `podman-hpc migrate` to convert it into a read-only SquashFS archive cached in DVS/node-local RAM at job launch.

## Generate and Submit FOM Jobs

Run `../run_perlmutter.sh` from the campaign folder (`2026-10-15/`), which pulls the prebuilt image, migrates it with `podman-hpc`, generates the 8-GPU `optcoms={off,on}` scripts via `perlmutter_fom_test.jl` (`sharded_atmosphere_simulation_run_nesap.jl`), and submits them with `sbatch`:

```bash
./run_perlmutter.sh
```

To profile a generated job at submission time:

```bash
PROFILER=nsys sbatch <path/to/submit.sh>
PROFILER=xprof sbatch <path/to/submit.sh>
```
