#!/usr/bin/env zsh
#SBATCH --partition=instruction
#SBATCH --time=00:02:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --output=parallel_sum_timing.output

cd $SLURM_SUBMIT_DIR
g++ -fopenmp parallel_sum_timing.cpp -o parallel_sum_timing 
./parallel_sum_timing