include("common_submission_generator.jl")

account = get(ENV, "VISTA_ACCOUNT", "")
queue = "gh-dev"
out_dir = joinpath(ENV["SCRATCH"], "GB25")
nccl_root = "/home1/apps/nvidia/Linux_aarch64/26.3/comm_libs/13.1/nccl"

submit   = false
run_name = "r_react_vista_"
time     = "00:40:00"
Ngpus      = [2, 4, 8]
comms_opts = ["off", "on"]

type     = "weak"

gpus_per_node = 1
cpus_per_task = 72

vista_config = JobConfig(; username, account, out_dir, time, cpus_per_task, Ngpus,
                         comms_opts, run_name, gpus_per_node, type, submit)

function vista_submit_job_writer(cfg::JobConfig, job_name, Nnodes, job_dir, Ngpu,
                                 resolution_fraction, project_path, run_file,
                                 comm::String)

    # x, y, z = (512, 512, 64)
    # x, y, z = (768, 768, 64)
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
module load gcc/13.2.0
module load cuda/13.1
module list

echo "Address-space limit in job: \$(ulimit -v)"

export TACC_NCCL_DIR=$(nccl_root)
export TACC_NCCL_LIB="\${TACC_NCCL_DIR}/lib"
export TACC_NCCL_INC="\${TACC_NCCL_DIR}/include"
export LD_LIBRARY_PATH="\${TACC_NCCL_LIB}\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
export CPATH="\${TACC_NCCL_INC}\${CPATH:+:\${CPATH}}"

export JULIA_CUDA_MEMORY_POOL=none
export JULIA_CUDA_USE_COMPAT=false
export JULIA_CPU_TARGET=generic
export NCCL_IB_DISABLE=0
export NCCL_BUFFSIZE=33554432

export REACTANT_GPU=cuda
export REACTANT_GPU_VERSION=13.1

export TACC_TASKS_PER_NODE=1
export XLA_FLAGS="--xla_gpu_shard_autotuning=false \${XLA_FLAGS:-}"

export GB25_COMMS_OPT=$(comm)

if [ "\${PROFILER:-}" = "nsys" ]; then
    PROFILER_CMD="nsys profile --trace=cuda,nvtx --sample=none --capture-range=cudaProfilerApi --capture-range-end=stop --cuda-graph-trace=node --output=$(job_dir)/nsys-job-%q{SLURM_JOB_ID}-rank-%q{OMPI_COMM_WORLD_RANK} env GB25_NSYS=true JULIA_CUDA_NSYS=nsys"
elif [ "\${PROFILER:-}" = "xprof" ]; then
    export GB25_XPROF=true
fi

ibrun -n $(Nnodes) $(job_dir)/launcher.sh \\
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
    $(Base.julia_cmd()[1]) --project=$(project_path) --startup-file=no \\
    --compiled-modules=strict -O0 \\
    $(run_file) --grid-x $(x) --grid-y $(y) --grid-z $(z)
"""
end

generate_and_submit(vista_submit_job_writer, vista_config; caller_file=@__FILE__)
