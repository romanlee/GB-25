include("common_submission_generator.jl")

account = get(ENV, "VISTA_ACCOUNT", "")
queue = "gh-dev"
out_dir = joinpath(ENV["SCRATCH"], "GB25")
sif = get(ENV, "GB25_SIF", joinpath(out_dir, "gb25_vista.sif"))

submit   = true
run_name = "r_react_vista_"
time     = "00:25:00"
Ngpus      = [8]
comms_opts = ["off", "on"]

type     = "weak"

gpus_per_node = 1
cpus_per_task = 72

vista_config = JobConfig(; username, account, out_dir, time, cpus_per_task, Ngpus,
                         comms_opts, run_name, gpus_per_node, type, submit, container = true)

function vista_submit_job_writer(cfg::JobConfig, job_name, Nnodes, job_dir, Ngpu,
                                 resolution_fraction, project_path, run_file,
                                 comm::String)

    x, y, z = (896, 896, 64)
    account_directive = isempty(cfg.account) ? "" : "#SBATCH --account=$(cfg.account)"

    """
#!/bin/bash -l

#SBATCH --partition=$(queue)
#SBATCH --job-name="$(job_name)"
#SBATCH --time=$(cfg.time)
#SBATCH --nodes=$(Nnodes)
#SBATCH --ntasks=$(Nnodes)
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=$(cfg.cpus_per_task)
$(account_directive)
#SBATCH --output=$(job_dir)/%j.out
#SBATCH --error=$(job_dir)/%j.err
#SBATCH --propagate=NONE

module reset
module load tacc-apptainer
module list

export NCCL_BUFFSIZE=33554432
export XLA_REACTANT_GPU_MEM_FRACTION=0.8

export TACC_TASKS_PER_NODE=1

# Nothing is mounted from the host apart from the driver (--nv): the NCCL core comes
# from the image (/opt/nccl/lib, first on the image's LD_LIBRARY_PATH) and talks to
# InfiniBand through NCCL's built-in NET/IB with the image's rdma-core.

export GB25_COMMS_OPT=$(comm)

if [ "\${PROFILER:-}" = "nsys" ]; then
    PROFILER_CMD="/usr/local/cuda/bin/nsys profile --trace=cuda,nvtx --sample=none --capture-range=cudaProfilerApi --capture-range-end=stop --cuda-graph-trace=node --output=$(job_dir)/nsys-job-%q{SLURM_JOB_ID}-rank-%q{OMPI_COMM_WORLD_RANK} env GB25_NSYS=true JULIA_CUDA_NSYS=nsys"
elif [ "\${PROFILER:-}" = "xprof" ]; then
    export GB25_XPROF=true
fi

ibrun -n $(Nnodes) apptainer exec --nv --scratch /tmp \\
    -B "\${SCRATCH}:\${SCRATCH}" \\
    $(sif) \\
    $(job_dir)/launcher.sh \\
    \${PROFILER_CMD} sh -c '
        export SLURM_STEP_NODELIST="\${SLURM_JOB_NODELIST}"
        export SLURM_STEP_NUM_NODES="\${SLURM_JOB_NUM_NODES}"
        export SLURM_NTASKS=$(Nnodes)
        export SLURM_NPROCS=$(Nnodes)
        export SLURM_STEP_NUM_TASKS=$(Nnodes)
        export SLURM_NTASKS_PER_NODE=1
        export SLURM_PROCID="\${OMPI_COMM_WORLD_RANK}"
        export SLURM_LOCALID="\${OMPI_COMM_WORLD_LOCAL_RANK}"
        exec "\$@"
    ' sh \\
    /usr/local/julia/bin/julia --project=/opt/gb25 --startup-file=no \\
    --compiled-modules=strict -O0 \\
    $(run_file) --grid-x $(x) --grid-y $(y) --grid-z $(z)
"""
end

isempty(Base.ARGS) && push!(Base.ARGS, "sharded_atmosphere_simulation_run_nesap.jl")
generate_and_submit(vista_submit_job_writer, vista_config; caller_file=@__FILE__)
