include("common_submission_generator.jl")

account = "m4672"
account = "m5096"
account = "m5176"

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

    # grid sizes for sharded_atmosphere_simulation_run.jl
    x, y, z = (512, 512, 64) # per-GPU size for 1°-IC Reactant test

#SBATCH -q premium
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
#SBATCH --mail-user=email@solidcompany.com
#SBATCH --mail-type=ALL

export SBATCH_ACCOUNT=$(cfg.account)
export SALLOC_ACCOUNT=$(cfg.account)
export JULIA_CUDA_MEMORY_POOL=none

export FI_CXI_RDZV_GET_MIN=0
export FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=16777216
# export MPICH_SMP_SINGLE_COPY_MODE=NONE
# export NCCL_DEBUG=INFO
# export FI_MR_CACHE_MONITOR=kdreg2
# export MPICH_GPU_SUPPORT_ENABLED=0
export NCCL_BUFFSIZE=33554432
export JULIA_CUDA_USE_COMPAT=false

export GB25_COMMS_OPT=$(comm)
CONTAINER_IMAGE="\${GB25_CONTAINER_IMAGE:-registry.gitlab.com/nersc/nesap/reactantanigans/gb25:perlmutter}"

if [ "\${PROFILER:-}" = "nsys" ]; then
    PROFILER_CMD="nsys profile --trace=cuda,nvtx --sample=none --capture-range=cudaProfilerApi --capture-range-end=stop --cuda-graph-trace=node --output=$(job_dir)/nsys-job-%q{SLURM_JOB_ID}-rank-%q{SLURM_PROCID} env GB25_NSYS=true JULIA_CUDA_NSYS=nsys"
elif [ "\${PROFILER:-}" = "xprof" ]; then
    export GB25_XPROF=true
fi

srun -n $(Nnodes) -c 32 -G $(Ngpu) --cpu-bind=verbose,cores \\
    podman-hpc run --rm --gpu --nccl \\
    --net=host --ipc=host --pid=host --env-host \\
    -v "\${SCRATCH}:\${SCRATCH}" \\
    "\${CONTAINER_IMAGE}" \\
    $(job_dir)/launcher.sh \${PROFILER_CMD} \\
    $(Base.julia_cmd()[1]) --project=/opt/gb25 --compiled-modules=strict -O0 \\
    $(run_file) --grid-x $(x) --grid-y $(y) --grid-z $(z)
"""
end

isempty(Base.ARGS) && push!(Base.ARGS, "sharded_atmosphere_simulation_run_nesap.jl")
generate_and_submit(perlmutter_submit_job_writer, perlmutter_config; caller_file=@__FILE__)
