#!/usr/bin/env zsh
#SBATCH --partition=instruction 
#SBATCH --time=00:01:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1 
#SBATCH --gpus-per-task=1 
#SBATCH --time=00:01:00
#SBATCH --output=hello.output

module load nvidia/cuda 
nvcc hello.cu -o hello 
./hello