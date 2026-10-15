# Vista Container (`gb25_vista.sif`)

Self-contained container build for running `GordonBell25` scaling benchmarks on **TACC Vista** (`linux/arm64`, 1x NVIDIA GH200 Grace Hopper Superchip per node, Mellanox NDR InfiniBand `mlx5` interconnect).

## What Is Inside the Container vs. From the Host

### Sealed Inside the Image
- **OS & Compiler Toolchain:** Ubuntu 24.04 (`aarch64`, `glibc 2.39`, `libstdc++`, `libcrypto.so.3`, `gcc 13`, `binutils`).
- **CUDA & NCCL via Julia JLLs:** `Reactant_jll` (`gpu = "cuda"`, `gpu_version = "13.1"`) and `CUDA_Runtime_jll` (`version = "13.1"`) provide the complete CUDA 13.1 runtime/math libraries, `ptxas`, and `libnccl.so.2` (NCCL `2.27.7`, unaffected by the `v2.29.2`-only `aarch64` weak-CAS bug) directly from the precompiled Julia depot.
- **GPUDirect RDMA & Profiling Tools:** `gdrcopy` (`libgdrapi.so` v2.4.4) and Nsight Systems CLI (`nsys`).
- **InfiniBand & MPI Stack:** Upstream Linux `rdma-core` (`libibverbs`, `ibverbs-providers` / `libmlx5`), `libucx0`, `libpmix2t64`, and `openmpi` (`libmpi.so`). Because InfiniBand verbs and PMIx are standard upstream Linux protocols, **zero** libraries from `/home1/apps` on the Vista host need to be mounted.
- **Julia & Precompiled Environment:** Julia `1.11.9` (`aarch64`, `/usr/local/julia/bin/julia`), the `GB-25` source repository at `/opt/gb25`, and a fully instantiated + `-O0` precompiled depot at `/usr/local/share/julia_depot` (`JULIA_CPU_TARGET=generic`, `REACTANT_GPU=cuda`, `REACTANT_GPU_VERSION=13.1`).

### Injected from the Host at Runtime (`tacc-apptainer`)
- **`--nv`:** Host kernel driver libraries (`libcuda.so.1`, `libnvidia-ml.so.1`) matching `/dev/nvidia*`. Device nodes (`/dev/infiniband/*`, `/dev/gdrdrv`) and Slurm/PMIx sockets are inherited automatically.
- **`-B $SCRATCH:$SCRATCH`:** Writable scratch filesystem for job scripts, logs, and profiler outputs. Each rank writes its runtime Julia/XLA scratch cache to node-local RAM (`/tmp/gb25_depot_${SLURM_JOB_ID}_${SLURM_PROCID}`).

## Build / Pull

### Option A: Build OCI Image (on an `arm64` builder, CI, or via `../build.sh`)
```bash
podman build --platform linux/arm64 -t gb25:vista -f container-vista/Containerfile .
```

### Option B: Pull Published Image to `.sif` on Vista
Pull the published OCI image from the container registry directly into `$SCRATCH/GB25/gb25_vista.sif` on Vista:
```bash
module load tacc-apptainer
apptainer pull --force "${SCRATCH}/GB25/gb25_vista.sif" docker://registry.gitlab.com/nersc/nesap/reactantanigans/gb25:vista
```

## Generate and Submit FOM Jobs

Run `../run_vista.sh` from the campaign folder (`2026-10-15/`), which pulls the prebuilt `.sif` image, generates the 8-GPU `optcoms={off,on}` scripts via `vista_fom_test.jl` (`sharded_atmosphere_simulation_run_nesap.jl`), and submits them with `sbatch`:

```bash
VISTA_ACCOUNT=<your_tacc_account> ./run_vista.sh
```

To profile a generated job at submission time:

```bash
PROFILER=nsys sbatch <path/to/submit.sh>
PROFILER=xprof sbatch <path/to/submit.sh>
```
