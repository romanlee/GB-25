include("common_submission_generator.jl")

account = get(ENV, "PERLMUTTER_ACCOUNT", "m5176")
queue = "regular"
out_dir = joinpath(ENV["SCRATCH"], "GB25")

# run params
submit   = true
run_name = "r_react_"
time     = "00:25:00"

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

export FI_CXI_RDZV_GET_MIN=0
export FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=16777216
export NCCL_BUFFSIZE=33554432

# The NCCL core comes from the image (/opt/nccl/lib). From the host we only take what
# is tied to the Slingshot install, mounted under /opt/host:
#   - the Cray libfabric (with the cxi provider) and libcxi, plus the /dev/cxi*
#     devices;
#   - the CUDA 13 aws-ofi-nccl plugin from the nccl/2.29.2-cu13 module. It links
#     libcudart.so.13, taken from the image's CUDA 13.1 runtime (/usr/local/cuda/lib64).
# Their other dependencies (libnl-3, libjson-c) come from the image. `podman-hpc --nccl`
# is not used: it injects an older libfabric/libcxi and a CUDA 12 plugin, and does not
# pass /dev/cxi* (the `tcp` fallback in job 60094975); the env it set is exported here.
# `--env-host` replaces the image's LD_LIBRARY_PATH, so it is passed with -e.
# /usr/lib64 holds the driver from --gpu.
# FI_PROVIDER and NCCL_NET make libfabric/NCCL fail instead of falling back.
HOST_NCCL_PLUGIN=/global/common/software/nersc9/nccl/2.29.2-cu13/plugin/lib
HOST_FABRIC=/opt/cray/libfabric/2.3.1
CXI_DEVS=\$(printf -- '--device %s ' /dev/cxi[0-9]*)
CONTAINER_LD_LIBRARY_PATH=/opt/nccl/lib:/opt/host/libfabric/lib64:/opt/host/cxi:/opt/host/nccl-plugin:/usr/lib64:/usr/local/cuda/lib64
export FI_PROVIDER=cxi
export NCCL_NET="AWS Libfabric"
export NCCL_SOCKET_IFNAME=hsn
export NCCL_CROSS_NIC=2
export NCCL_NET_GDR_LEVEL=PHB
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_MR_CACHE_MONITOR=userfaultfd
export FI_CXI_RDZV_THRESHOLD=0
# Per-rank NCCL init/transport log, to confirm which core + plugin are in use.
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,NET,ENV
export NCCL_DEBUG_FILE=$(job_dir)/nccl.%h.%p.log

export GB25_COMMS_OPT=$(comm)

if [ "\${PROFILER:-}" = "nsys" ]; then
    PROFILER_CMD="/usr/local/cuda/bin/nsys profile --trace=cuda,nvtx --sample=none --capture-range=cudaProfilerApi --capture-range-end=stop --cuda-graph-trace=node --output=$(job_dir)/nsys-job-%q{SLURM_JOB_ID}-rank-%q{SLURM_PROCID} env GB25_NSYS=true JULIA_CUDA_NSYS=nsys"
elif [ "\${PROFILER:-}" = "xprof" ]; then
    export GB25_XPROF=true
fi

srun -n $(Nnodes) -c 32 -G $(Ngpu) --cpu-bind=verbose,cores \\
    podman-hpc run --rm --gpu \\
    --net=host --ipc=host --pid=host --env-host \\
    \${CXI_DEVS} \\
    -v "\${SCRATCH}:\${SCRATCH}" \\
    -v "\${HOST_FABRIC}:/opt/host/libfabric:ro" \\
    -v /usr/lib64/libcxi.so.1:/opt/host/cxi/libcxi.so.1:ro \\
    -v "\${HOST_NCCL_PLUGIN}:/opt/host/nccl-plugin:ro" \\
    -e LD_LIBRARY_PATH="\${CONTAINER_LD_LIBRARY_PATH}" \\
    $(image) \\
    $(job_dir)/launcher.sh \${PROFILER_CMD} \\
    /usr/local/julia/bin/julia --project=/opt/gb25 --compiled-modules=strict -O0 \\
    $(run_file) --grid-x $(x) --grid-y $(y) --grid-z $(z)
"""
end

isempty(Base.ARGS) && push!(Base.ARGS, "sharded_atmosphere_simulation_run_nesap.jl")
generate_and_submit(perlmutter_submit_job_writer, perlmutter_config; caller_file=@__FILE__)
