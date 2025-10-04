#!/usr/bin/env zsh
#SBATCH --partition=instruction 
#SBATCH --time=00:01:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --gpus-per-task=1
#SBATCH --time=00:01:00
#SBATCH --output=vector_add.output

module load nvidia/cuda
nvcc vector_add.cu -o vector_add 
./vector_add