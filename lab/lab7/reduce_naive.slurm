#!/usr/bin/env zsh 
#SBATCH--partition=instruction 
#SBATCH--time=00:03:00 
#SBATCH--ntasks=1 
#SBATCH--cpus-per-task=1 
#SBATCH--gpus-per-task=1 
#SBATCH--output=reduce_naive.output 
cd $SLURM_SUBMIT_DIR 
module load nvidia/cuda 
nvcc reduce_naive.cu-o reduce_naive 
./reduce_naive