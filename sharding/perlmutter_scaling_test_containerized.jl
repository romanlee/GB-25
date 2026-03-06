include("common_submission_generator.jl")

account = "m4672"
account = "m5096"
account = "m5176"

# queue = "regular"
queue = "debug"
out_dir = joinpath(ENV["SCRATCH"], "GB25")

# run params
submit   = true
run_name = "r_react_"
# time     = "01:00:00"
time     = "00:10:00"
Ngpus    = [4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048]
Ngpus    = [4]
type     = "weak"

container_image = get(ENV, "GB25_CONTAINER_IMAGE", "reactant:latest")

gpus_per_node = 4
cpus_per_task = 16

perlmutter_config = JobConfig(; username, account, out_dir, time, cpus_per_task, Ngpus,
                              run_name, gpus_per_node, type, submit)

function perlmutter_submit_job_writer(cfg::JobConfig, job_name, Nnodes, job_dir, Ngpu,
                                      resolution_fraction, project_path, run_file)
job_root = dirname(job_dir)

"""
#!/bin/bash -l

#SBATCH -C gpu
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

# Equivalent to \$NCCL_DIR/lib/libnccl.so but will also work if module doesn't set NCCL_DIR
# export NCCL_LIB_PATH=\$(julia -e "n=\\"libnccl\\";using Libdl;dlopen(n);filter(contains(n),dllist())|>first|>println")

#
# HACKS to get this to work on Perlmutter
#

# export LD_PRELOAD=\$NCCL_LIB_PATH
export FI_CXI_RDZV_GET_MIN=0
export FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=16777216
# export MPICH_SMP_SINGLE_COPY_MODE=NONE
# export NCCL_DEBUG=INFO
# export FI_MR_CACHE_MONITOR=kdreg2
# export MPICH_GPU_SUPPORT_ENABLED=0
export NCCL_BUFFSIZE=33554432
export JULIA_CUDA_USE_COMPAT=false
srun -n $(Nnodes) -c 32 -G $(Ngpu) --cpu-bind=verbose,cores \\
    $(job_dir)/launcher.sh \\
    podman-hpc run --rm --gpu \\
    --env SLURM_JOB_ID \\
    --env SLURM_STEP_NODELIST \\
    --env SLURM_NTASKS \\
    --env SLURM_PROCID \\
    --env SLURM_LOCALID \\
    --env CUDA_VISIBLE_DEVICES \\
    --env XLA_FLAGS \\
    --env XLA_REACTANT_GPU_MEM_FRACTION \\
    --env FI_CXI_RDZV_GET_MIN \\
    --env FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD \\
    --env NCCL_BUFFSIZE \\
    --env JULIA_CUDA_USE_COMPAT \\
    --env JULIA_CUDA_MEMORY_POOL \\
    --env JULIA_DEBUG \\
    --volume $(project_path):$(project_path) \\
    --volume $(job_root):$(job_root) \\
    --workdir $(project_path) \\
    $(container_image) \\
    julia --project=$(project_path) --compiled-modules=strict -O0 $(run_file)
"""
end

generate_and_submit(perlmutter_submit_job_writer, perlmutter_config; caller_file=@__FILE__)
