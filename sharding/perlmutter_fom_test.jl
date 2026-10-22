include("common_submission_generator.jl")

account = get(ENV, "PERLMUTTER_ACCOUNT", "m5176")
queue = "regular"
out_dir = joinpath(ENV["SCRATCH"], "GB25")

# run params
submit   = true
run_name = "r_react_"
time     = "00:40:00"

Ngpus      = [8]
comms_opts = ["off", "on"]

type     = "weak"

gpus_per_node = 4
cpus_per_task = 16

perlmutter_config = JobConfig(; username, account, out_dir, time, cpus_per_task, Ngpus, comms_opts,
                              run_name, gpus_per_node, type, submit)

function perlmutter_submit_job_writer(cfg::JobConfig, job_name, Nnodes, job_dir, Ngpu,
                                      resolution_fraction, project_path, run_file,
                                      comm::String)

    x, y, z = (512, 512, 64)
    image = get(ENV, "GB25_IMAGE", "ghcr.io/prontolab/gb-25:latest")

                """
#!/bin/bash -l

#SBATCH -C gpu&hbm40g
#SBATCH -q $(queue)
#SBATCH --gpu-bind=none
#SBATCH --job-name="$(job_name)"
#SBATCH --time=$(cfg.time)
#SBATCH --nodes=$(Nnodes)
#SBATCH --account=$(cfg.account)
#SBATCH --output=$(job_dir)/%j.out
#SBATCH --error=$(job_dir)/%j.err

export SBATCH_ACCOUNT=$(cfg.account)
export SALLOC_ACCOUNT=$(cfg.account)
export JULIA_CUDA_MEMORY_POOL=none

export FI_CXI_RDZV_GET_MIN=0
export FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=16777216
export NCCL_BUFFSIZE=33554432
export JULIA_CUDA_USE_COMPAT=false

# The aws-ofi-nccl plugin injected by `podman-hpc --nccl` is built against CUDA 12
# (needs libcudart.so.12), fails to load in this CUDA 13 image, and NCCL silently
# falls back to TCP sockets. Use the host's nccl/2.29.2-cu13 module instead: its
# libnccl.so.2 *and* its CUDA 13 plugin (prepended to LD_LIBRARY_PATH inside the
# container below, in the module's order), plus the env that module sets. Mounting
# only the plugin left Reactant_jll's bundled libnccl.so.2 in use, and optcoms=off
# ran ~35x slower than bare metal (job 60071928). NCCL_NET makes NCCL fail instead
# of falling back.
#
# With the host core + plugin loaded (job 60094975) it was still ~27x slower:
# libfabric picked the `tcp` provider and striped traffic over every IP interface,
# nmn0 included. `--nccl` puts its own, older libfabric.so.1/libcxi.so.1 first on
# LD_LIBRARY_PATH and does not pass /dev/cxi* into the container. Mount the host's
# Cray libfabric and libcxi (ahead of everything), pass the cxi devices (plus
# gdrdrv for libfabric's gdrcopy, if present), and set FI_PROVIDER=cxi so
# libfabric fails instead of falling back to tcp.
HOST_NCCL=/global/common/software/nersc9/nccl/2.29.2-cu13
HOST_CUDART=/opt/nvidia/hpc_sdk/Linux_x86_64/26.5/cuda/13.2/lib64
HOST_FABRIC=/opt/cray/libfabric/2.3.1
CXI_DEVS=\$(for d in /dev/cxi[0-9]* /dev/gdrdrv; do [ -e "\$d" ] && printf -- '--device %s ' "\$d"; done)
export FI_PROVIDER=cxi
export NCCL_NET="AWS Libfabric"
export NCCL_SOCKET_IFNAME=hsn
export NCCL_CROSS_NIC=2
export NCCL_NET_GDR_LEVEL=PHB
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_CXI_RDZV_THRESHOLD=0
# Per-rank NCCL init/transport log, to confirm which core + plugin are in use.
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,NET,ENV
export NCCL_DEBUG_FILE=$(job_dir)/nccl.%h.%p.log

export GB25_COMMS_OPT=$(comm)

if [ "\${PROFILER:-}" = "nsys" ]; then
    PROFILER_CMD="nsys profile --trace=cuda,nvtx --sample=none --capture-range=cudaProfilerApi --capture-range-end=stop --cuda-graph-trace=node --output=$(job_dir)/nsys-job-%q{SLURM_JOB_ID}-rank-%q{SLURM_PROCID} env GB25_NSYS=true JULIA_CUDA_NSYS=nsys"
elif [ "\${PROFILER:-}" = "xprof" ]; then
    export GB25_XPROF=true
fi

srun -n $(Nnodes) -c 32 -G $(Ngpu) --cpu-bind=verbose,cores \\
    podman-hpc run --rm --gpu --nccl \\
    --net=host --ipc=host --pid=host --env-host \\
    \${CXI_DEVS} \\
    -v "\${SCRATCH}:\${SCRATCH}" \\
    -v "\${HOST_FABRIC}:/opt/host-libfabric:ro" \\
    -v /usr/lib64/libcxi.so.1:/opt/host-cxi/libcxi.so.1:ro \\
    -v "\${HOST_NCCL}/lib:/opt/host-nccl:ro" \\
    -v "\${HOST_NCCL}/plugin/lib:/opt/host-nccl-plugin:ro" \\
    -v "\${HOST_CUDART}:/opt/host-cudart:ro" \\
    $(image) \\
    bash -c 'export LD_LIBRARY_PATH="/opt/host-libfabric/lib64:/opt/host-cxi:/opt/host-nccl:/opt/host-nccl-plugin:\${LD_LIBRARY_PATH}:/opt/host-cudart"; exec "\$@"' gb25 \\
    $(job_dir)/launcher.sh \${PROFILER_CMD} \\
    /usr/local/julia/bin/julia --project=/opt/gb25 --compiled-modules=strict -O0 \\
    $(run_file) --grid-x $(x) --grid-y $(y) --grid-z $(z)
"""
end

isempty(Base.ARGS) && push!(Base.ARGS, "sharded_atmosphere_simulation_run_nesap.jl")
generate_and_submit(perlmutter_submit_job_writer, perlmutter_config; caller_file=@__FILE__)
