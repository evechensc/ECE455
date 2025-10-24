#!/usr/bin/env zsh
#SBATCH --partition=instruction
#SBATCH --time=00:03:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --gpus-per-task=1
#SBATCH --output=reduce_shared.output

set -e
cd "$SLURM_SUBMIT_DIR"

# Try a CUDA version likely to match the node drivers.
# Replace with one that exists on your cluster (see `module avail nvidia/cuda`)
module purge
module load nvidia/cuda/12.1   # ← if this still fails, try 12.0 or 11.8

echo "==== Diagnostics ===="
which nvcc || true
nvcc --version || true
nvidia-smi || true
echo "====================="

# Compile for your GPU arch to embed SASS (reduces PTX JIT needs)
# Examples: sm_70 (V100), sm_75 (T4), sm_80 (A100), sm_89 (L40S), sm_90 (H100)
# If you’re unsure, run nvidia-smi to identify the GPU model and pick the matching sm_XX.
nvcc -O3 -arch=sm_80 reduce_shared.cu -o reduce_shared

./reduce_shared
