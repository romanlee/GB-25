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
# falls back to TCP sockets. Use the CUDA 13 plugin from the host's nccl/2.29.2-cu13
# module instead (prepended to LD_LIBRARY_PATH inside the container below), plus
# the env that module sets. NCCL_NET makes NCCL fail instead of falling back.
HOST_NCCL=/global/common/software/nersc9/nccl/2.29.2-cu13
HOST_CUDART=/opt/nvidia/hpc_sdk/Linux_x86_64/26.5/cuda/13.2/lib64
export NCCL_NET="AWS Libfabric"
export NCCL_SOCKET_IFNAME=hsn
export NCCL_CROSS_NIC=2
export NCCL_NET_GDR_LEVEL=PHB
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_CXI_RDZV_THRESHOLD=0

export GB25_COMMS_OPT=$(comm)

if [ "\${PROFILER:-}" = "nsys" ]; then
    PROFILER_CMD="nsys profile --trace=cuda,nvtx --sample=none --capture-range=cudaProfilerApi --capture-range-end=stop --cuda-graph-trace=node --output=$(job_dir)/nsys-job-%q{SLURM_JOB_ID}-rank-%q{SLURM_PROCID} env GB25_NSYS=true JULIA_CUDA_NSYS=nsys"
elif [ "\${PROFILER:-}" = "xprof" ]; then
    export GB25_XPROF=true
fi

srun -n $(Nnodes) -c 32 -G $(Ngpu) --cpu-bind=verbose,cores \\
    podman-hpc run --rm --gpu --nccl \\
    --net=host --ipc=host --pid=host --env-host \\
    -v "\${SCRATCH}:\${SCRATCH}" \\
    -v "\${HOST_NCCL}/plugin/lib:/opt/host-nccl-plugin:ro" \\
    -v "\${HOST_CUDART}:/opt/host-cudart:ro" \\
    $(image) \\
    bash -c 'export LD_LIBRARY_PATH="/opt/host-nccl-plugin:\${LD_LIBRARY_PATH}:/opt/host-cudart"; exec "\$@"' gb25 \\
    $(job_dir)/launcher.sh \${PROFILER_CMD} \\
    /usr/local/julia/bin/julia --project=/opt/gb25 --compiled-modules=strict -O0 \\
    $(run_file) --grid-x $(x) --grid-y $(y) --grid-z $(z)
"""
end

isempty(Base.ARGS) && push!(Base.ARGS, "sharded_atmosphere_simulation_run_nesap.jl")
generate_and_submit(perlmutter_submit_job_writer, perlmutter_config; caller_file=@__FILE__)
